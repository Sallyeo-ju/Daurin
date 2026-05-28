import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

export type UserDocument = HydratedDocument<User>;

@Schema({ timestamps: true })
export class User {
  @Prop({ required: true, unique: true, trim: true, lowercase: true })
  username!: string;

  @Prop({ required: true, unique: true, trim: true, lowercase: true })
  email!: string;

  @Prop({ required: false, trim: true })
  phoneNumber?: string;

  @Prop({ required: false })
  password?: string;

  @Prop({ required: false, length: 6 })
  pin?: string;

  @Prop({ required: false })
  provider?: string;

  @Prop({ required: false })
  photoUrl?: string;
}

export const UserSchema = SchemaFactory.createForClass(User);
