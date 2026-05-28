import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

export type ChatThreadDocument = HydratedDocument<ChatThread>;

@Schema({ timestamps: true })
export class ChatThread {
  @Prop({ required: true, unique: true, index: true, trim: true })
  threadId!: string;

  @Prop({ required: true, trim: true })
  sellerId!: string;

  @Prop({ required: true, trim: true })
  sellerUsername!: string;

  @Prop({ required: true, trim: true })
  sellerName!: string;

  @Prop({ required: true, trim: true, lowercase: true })
  sellerEmail!: string;

  @Prop({ required: true, trim: true })
  buyerName!: string;

  @Prop({ required: true, trim: true, lowercase: true })
  buyerEmail!: string;

  @Prop({ required: true, default: [] })
  participants!: string[];

  @Prop({ default: 'Mulai chat' })
  lastMessage!: string;

  @Prop({ default: Date.now })
  lastMessageAt!: Date;
}

export const ChatThreadSchema = SchemaFactory.createForClass(ChatThread);