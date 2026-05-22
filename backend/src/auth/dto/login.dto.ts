import { IsOptional, IsString } from 'class-validator';

export class LoginDto {
  @IsOptional()
  @IsString()
  identifier?: string;

  // Backward compatibility for older clients that still send `email`.
  @IsOptional()
  @IsString()
  email?: string;

  @IsString()
  password!: string;
}
