import { IsOptional, IsString, IsNotEmpty } from 'class-validator';

export class GoogleAuthDto {
  @IsNotEmpty()
  @IsString()
  idToken!: string;

  @IsOptional()
  @IsString()
  email?: string;

  @IsOptional()
  @IsString()
  displayName?: string;

  @IsOptional()
  @IsString()
  photoUrl?: string;
}
