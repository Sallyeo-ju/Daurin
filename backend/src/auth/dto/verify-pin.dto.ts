import { IsNotEmpty, IsString, Matches } from 'class-validator';

export class VerifyPinDto {
  @IsString()
  @IsNotEmpty()
  identifier!: string;

  @IsString()
  @Matches(/^\d{6}$/, {
    message: 'PIN must be exactly 6 digits',
  })
  pin!: string;
}