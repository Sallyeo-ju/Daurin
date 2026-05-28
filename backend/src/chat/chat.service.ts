import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { CreateChatThreadDto } from './dto/create-chat-thread.dto';
import { SendChatMessageDto } from './dto/send-chat-message.dto';
import { ChatMessage, ChatMessageDocument } from './schemas/chat-message.schema';
import { ChatThread, ChatThreadDocument } from './schemas/chat-thread.schema';

@Injectable()
export class ChatService {
  constructor(
    @InjectModel(ChatThread.name)
    private readonly threadModel: Model<ChatThreadDocument>,
    @InjectModel(ChatMessage.name)
    private readonly messageModel: Model<ChatMessageDocument>,
  ) {}

  async upsertThread(dto: CreateChatThreadDto) {
    this.assertThreadParticipants(dto.sellerEmail, dto.buyerEmail);

    const threadId = this.resolveThreadId(dto);
    const thread = await this.threadModel
      .findOneAndUpdate(
        { threadId },
        {
          $set: {
            threadId,
            sellerId: dto.sellerId.trim(),
            sellerUsername: dto.sellerUsername.trim(),
            sellerName: dto.sellerName.trim(),
            sellerEmail: this.normalizeEmail(dto.sellerEmail),
            buyerName: dto.buyerName.trim(),
            buyerEmail: this.normalizeEmail(dto.buyerEmail),
            participants: [
              this.normalizeEmail(dto.sellerEmail),
              this.normalizeEmail(dto.buyerEmail),
            ],
          },
          $setOnInsert: {
            lastMessage: dto.initialMessage?.trim() || 'Mulai chat',
            lastMessageAt: new Date(),
          },
        },
        { new: true, upsert: true },
      )
      .exec();

    if (!thread) {
      throw new NotFoundException('Thread chat tidak ditemukan.');
    }

    return thread;
  }

  async findThreadsForUser(userEmail: string) {
    const normalizedEmail = this.normalizeEmail(userEmail);
    if (!normalizedEmail) {
      return [];
    }

    return this.threadModel
      .find({ participants: normalizedEmail })
      .sort({ lastMessageAt: -1, updatedAt: -1 })
      .exec();
  }

  async findMessages(threadId: string) {
    return this.messageModel
      .find({ threadId: threadId.trim() })
      .sort({ sentAt: 1, createdAt: 1 })
      .exec();
  }

  async sendMessage(dto: SendChatMessageDto) {
    const thread = await this.upsertThread(dto);
    const senderEmail = this.normalizeEmail(dto.senderEmail);
    const senderName = dto.senderName.trim();
    const text = dto.text.trim();

    if (!senderEmail || !text) {
      throw new BadRequestException('Pesan tidak valid.');
    }

    const isSeller = senderEmail === thread.sellerEmail;
    const receiverEmail = isSeller ? thread.buyerEmail : thread.sellerEmail;
    const receiverName = isSeller ? thread.buyerName : thread.sellerName;

    const message = await this.messageModel.create({
      threadId: thread.threadId,
      senderEmail,
      senderName,
      receiverEmail,
      receiverName,
      text,
      sentAt: new Date(),
    });

    await this.threadModel
      .findOneAndUpdate(
        { threadId: thread.threadId },
        { lastMessage: text, lastMessageAt: message.sentAt },
        { new: true },
      )
      .exec();

    return { thread, message };
  }

  private resolveThreadId(dto: CreateChatThreadDto) {
    const providedThreadId = dto.threadId?.trim();
    if (providedThreadId) {
      return providedThreadId;
    }

    return [
      dto.sellerId.trim().toLowerCase(),
      this.normalizeEmail(dto.buyerEmail),
    ].join('__');
  }

  private normalizeEmail(value: string) {
    return value.trim().toLowerCase();
  }

  private assertThreadParticipants(sellerEmail: string, buyerEmail: string) {
    if (!sellerEmail.trim() || !buyerEmail.trim()) {
      throw new BadRequestException('Email seller dan buyer wajib ada.');
    }
  }
}