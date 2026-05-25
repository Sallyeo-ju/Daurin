import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

export type ItemDocument = HydratedDocument<Item>;

@Schema({ timestamps: true })
export class Item {
  @Prop({ required: true, trim: true })
  name!: string;

  @Prop({ required: true, min: 0 })
  price!: number;

  @Prop({ required: true, trim: true })
  location!: string;

  @Prop({ required: false, trim: true })
  category?: string;

  @Prop({ required: false, trim: true })
  description?: string;

  @Prop()
  imageUrl?: string;

  @Prop({ default: false })
  isPromoted!: boolean;

  @Prop({ min: 0, max: 100 })
  discountPercent?: number;

  @Prop({ min: 0 })
  discountedPrice?: number;

  @Prop({ default: 1, min: 0 })
  quantity!: number;

  @Prop()
  promoNote?: string;

  @Prop({ default: true })
  isAvailable!: boolean;
}

export const ItemSchema = SchemaFactory.createForClass(Item);
