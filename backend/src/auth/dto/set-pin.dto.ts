import { IsNotEmpty, IsString, Matches } from 'class-validator';

export class SetPinDto {
  @IsNotEmpty()
  @IsString()
  identifier!: string;

  @IsNotEmpty()
  @IsString()
  @Matches(/^\d{6}$/, { message: 'PIN must be 6 digits' })
  pin!: string;
}
