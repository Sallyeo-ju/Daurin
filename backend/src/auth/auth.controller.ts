import {
  Controller,
  Post,
  Patch,
  Get,
  Delete,
  Body,
  Param,
  UseGuards,
  Request,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './guards/jwt-auth.guards'; // Adjust path if needed
import { ChangePasswordDto } from './dto/change-password.dto';
import { CreateAddressDto } from './dto/create-address-dto';
import { GoogleAuthDto } from './dto/google-auth.dto';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { UpdateAddressDto } from './dto/update-address-dto';
import { SetPinDto } from './dto/set-pin.dto';
import { VerifyPinDto } from './dto/verify-pin.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  async register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('login')
  async login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post('google')
  async loginWithGoogle(@Body() dto: GoogleAuthDto) {
    return this.authService.loginWithGoogle(dto);
  }

  @Post('set-pin')
  async setPin(@Body() dto: SetPinDto) {
    return this.authService.setPin(dto);
  }

  @Post('verify-pin')
  async verifyPin(@Body() dto: VerifyPinDto) {
    return this.authService.verifyPin(dto);
  }

  @Patch('profile/picture')
  @UseGuards(JwtAuthGuard)
  async updateProfilePicture(
    @Request() req: any,
    @Body() body: { imageUrl: string },
  ) {
    return this.authService.updateProfilePicture(req.user.id, body.imageUrl);
  }

  @Post('change-password')
  @UseGuards(JwtAuthGuard)
  async changePassword(
    @Request() req: any,
    @Body() dto: ChangePasswordDto,
  ) {
    return this.authService.changePassword(req.user.id, dto);
  }

  @Post('addresses')
  @UseGuards(JwtAuthGuard)
  async createAddress(
    @Request() req: any,
    @Body() dto: CreateAddressDto,
  ) {
    return this.authService.createAddress(req.user.id, dto);
  }

  @Get('addresses')
  @UseGuards(JwtAuthGuard)
  async getAddresses(@Request() req: any) {
    return this.authService.getAddresses(req.user.id);
  }

  @Patch('addresses/:index')
  @UseGuards(JwtAuthGuard)
  async updateAddress(
    @Request() req: any,
    @Param('index') index: string,
    @Body() dto: UpdateAddressDto,
  ) {
    return this.authService.updateAddress(req.user.id, parseInt(index), dto);
  }

  @Delete('addresses/:index')
  @UseGuards(JwtAuthGuard)
  async deleteAddress(
    @Request() req: any,
    @Param('index') index: string,
  ) {
    return this.authService.deleteAddress(req.user.id, parseInt(index));
  }
}