import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { VerifyPinDto } from './dto/verify-pin.dto';
import { SetPinDto } from './dto/set-pin.dto';
import { GoogleAuthDto } from './dto/google-auth.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  register(@Body() registerDto: RegisterDto) {
    return this.authService.register(registerDto);
  }

  @Post('login')
  login(@Body() loginDto: LoginDto) {
    return this.authService.login(loginDto);
  }

  @Post('google')
  google(@Body() dto: GoogleAuthDto) {
    return this.authService.googleLogin(dto);
  }

  @Post('verify-pin')
  verifyPin(@Body() verifyPinDto: VerifyPinDto) {
    return this.authService.verifyPin(verifyPinDto);
  }

  @Post('set-pin')
  setPin(@Body() dto: SetPinDto) {
    return this.authService.setPin(dto);
  }
}
