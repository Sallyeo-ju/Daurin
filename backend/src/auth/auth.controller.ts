import { Controller, Post, Patch, Get, Delete, Body, Param, UseGuards, Request } from '@nestjs/common';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './guards/jwt-auth.guard'; // Adjust path if needed
import { ChangePasswordDto } from './dto/change-password.dto';
import { CreateAddressDto } from './dto/create-address.dto';
import { UpdateAddressDto } from './dto/update-address.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  // ... existing endpoints ...

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