import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

export type ChatMessageDocument = HydratedDocument<ChatMessage>;

@Schema({ timestamps: true })
export class ChatMessage {
  @Prop({ required: true, trim: true, index: true })
  threadId!: string;

  @Prop({ required: true, trim: true, lowercase: true })
  senderEmail!: string;

  @Prop({ required: true, trim: true })
  senderName!: string;

  @Prop({ required: true, trim: true, lowercase: true })
  receiverEmail!: string;

  @Prop({ required: true, trim: true })
  receiverName!: string;

  @Prop({ required: true, trim: true })
  text!: string;

  @Prop({ default: Date.now })
  sentAt!: Date;
}

export const ChatMessageSchema = SchemaFactory.createForClass(ChatMessage);