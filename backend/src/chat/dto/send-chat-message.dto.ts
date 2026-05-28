export class SendChatMessageDto {
  threadId?: string;
  sellerId!: string;
  sellerUsername!: string;
  sellerName!: string;
  sellerEmail!: string;
  buyerName!: string;
  buyerEmail!: string;
  senderEmail!: string;
  senderName!: string;
  text!: string;
}