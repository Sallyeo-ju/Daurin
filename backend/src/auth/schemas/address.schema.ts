import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

export type AddressDocument = HydratedDocument<Address>;

@Schema({ timestamps: true })
export class Address {
  @Prop({ required: true, trim: true })
  street!: string;

  @Prop({ required: true, trim: true })
  city!: string;

  @Prop({ required: true, trim: true })
  province!: string;

  @Prop({ required: true, trim: true })
  postalCode!: string;

  @Prop({ required: false, trim: true })
  rt?: string;

  @Prop({ required: false, trim: true })
  rw?: string;

  @Prop({ default: false })
  isDefault!: boolean;
}

export const AddressSchema = SchemaFactory.createForClass(Address);