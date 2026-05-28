export class CreateChatThreadDto {
  threadId?: string;
  sellerId!: string;
  sellerUsername!: string;
  sellerName!: string;
  sellerEmail!: string;
  buyerName!: string;
  buyerEmail!: string;
  initialMessage?: string;
}