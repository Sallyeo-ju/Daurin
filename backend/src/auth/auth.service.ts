import { BadRequestException, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import * as bcrypt from 'bcrypt';
import { User, UserDocument } from './schemas/user.schema';
import { Address } from './schemas/address.schema';
import { CreateAddressDto } from './dto/create-address-dto';
import { UpdateAddressDto } from './dto/update-address-dto';
import { ChangePasswordDto } from './dto/change-password.dto';

@Injectable()
export class AuthService {
  constructor(
    @InjectModel(User.name) private readonly userModel: Model<UserDocument>,
  ) {}

  async findByUsername(username: string) {
    return this.userModel.findOne({ username: username.toLowerCase() });
  }

  async findByEmail(email: string) {
    return this.userModel.findOne({ email: email.toLowerCase() });
  }

  async findById(id: string) {
    return this.userModel.findById(id);
  }

  async updateProfilePicture(userId: string, imageUrl: string) {
    const user = await this.userModel.findByIdAndUpdate(
      userId,
      { profilePictureUrl: imageUrl },
      { new: true },
    );

    if (!user) {
      throw new NotFoundException('User tidak ditemukan.');
    }

    return user;
  }

  async changePassword(userId: string, dto: ChangePasswordDto) {
    if (dto.newPassword !== dto.confirmPassword) {
      throw new BadRequestException('Password baru tidak cocok.');
    }

    const user = await this.userModel.findById(userId);
    if (!user) {
      throw new NotFoundException('User tidak ditemukan.');
    }

    if (!user.password) {
      throw new BadRequestException('User tidak memiliki password.');
    }

    const isPasswordValid = await bcrypt.compare(dto.currentPassword, user.password);
    if (!isPasswordValid) {
      throw new UnauthorizedException('Password lama tidak sesuai.');
    }

    if (dto.currentPassword === dto.newPassword) {
      throw new BadRequestException('Password baru harus berbeda dari password lama.');
    }

    const hashedPassword = await bcrypt.hash(dto.newPassword, 10);
    user.password = hashedPassword;
    await user.save();

    return { message: 'Password berhasil diubah.' };
  }

  async createAddress(userId: string, dto: CreateAddressDto) {
    const user = await this.userModel.findById(userId);
    if (!user) {
      throw new NotFoundException('User tidak ditemukan.');
    }

    const newAddress: Address = {
      street: dto.street,
      city: dto.city,
      province: dto.province,
      postalCode: dto.postalCode,
      rt: dto.rt,
      rw: dto.rw,
      isDefault: dto.isDefault || false,
    };

    // If this is the first address or marked as default, set it as default
    if (user.addresses.length === 0 || dto.isDefault) {
      user.addresses.forEach((addr) => (addr.isDefault = false));
      newAddress.isDefault = true;
    }

    user.addresses.push(newAddress);
    await user.save();

    return user.addresses[user.addresses.length - 1];
  }

  async getAddresses(userId: string) {
    const user = await this.userModel.findById(userId);
    if (!user) {
      throw new NotFoundException('User tidak ditemukan.');
    }

    return user.addresses;
  }

  async updateAddress(userId: string, addressIndex: number, dto: UpdateAddressDto) {
    const user = await this.userModel.findById(userId);
    if (!user) {
      throw new NotFoundException('User tidak ditemukan.');
    }

    if (addressIndex < 0 || addressIndex >= user.addresses.length) {
      throw new NotFoundException('Alamat tidak ditemukan.');
    }

    const address = user.addresses[addressIndex];
    Object.assign(address, dto);

    // If marking as default, unset others
    if (dto.isDefault) {
      user.addresses.forEach((addr, idx) => {
        addr.isDefault = idx === addressIndex;
      });
    }

    await user.save();
    return user.addresses[addressIndex];
  }

  async deleteAddress(userId: string, addressIndex: number) {
    const user = await this.userModel.findById(userId);
    if (!user) {
      throw new NotFoundException('User tidak ditemukan.');
    }

    if (addressIndex < 0 || addressIndex >= user.addresses.length) {
      throw new NotFoundException('Alamat tidak ditemukan.');
    }

    user.addresses.splice(addressIndex, 1);

    // If deleted address was default, set first as default
    if (user.addresses.length > 0 && !user.addresses.some((a) => a.isDefault)) {
      user.addresses[0].isDefault = true;
    }

    await user.save();
    return { message: 'Alamat berhasil dihapus.' };
  }
}