import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { JwtService } from '@nestjs/jwt';
import { Model } from 'mongoose';
import * as bcrypt from 'bcrypt';
import { User, UserDocument } from './schemas/user.schema';
import { Address } from './schemas/address.schema';
import { CreateAddressDto } from './dto/create-address-dto';
import { GoogleAuthDto } from './dto/google-auth.dto';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { UpdateAddressDto } from './dto/update-address-dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { SetPinDto } from './dto/set-pin.dto';
import { VerifyPinDto } from './dto/verify-pin.dto';

@Injectable()
export class AuthService {
  constructor(
    @InjectModel(User.name) private readonly userModel: Model<UserDocument>,
    private readonly jwtService: JwtService,
  ) {}

  private sanitizeUser(user: UserDocument | null) {
    if (!user) {
      return null;
    }

    const userObject = user.toObject ? user.toObject() : (user as any);
    const { password, pin, __v, ...rest } = userObject;
    return {
      ...rest,
      id: userObject._id?.toString?.() ?? userObject.id?.toString?.() ?? '',
    };
  }

  private createAuthResponse(user: UserDocument) {
    const userPayload = this.sanitizeUser(user);
    return {
      accessToken: this.jwtService.sign({
        sub: userPayload?.id,
        email: userPayload?.email,
        username: userPayload?.username,
      }),
      user: userPayload,
    };
  }

  async register(dto: RegisterDto) {
    const username = dto.username.trim().toLowerCase();
    const email = dto.email.trim().toLowerCase();

    const existingUser = await this.userModel.findOne({
      $or: [{ username }, { email }],
    });

    if (existingUser) {
      throw new ConflictException('Username atau email sudah terdaftar.');
    }

    const hashedPassword = await bcrypt.hash(dto.password, 10);
    const user = await this.userModel.create({
      username,
      email,
      phoneNumber: dto.phoneNumber.trim(),
      password: hashedPassword,
      pin: dto.pin?.trim(),
    });

    return {
      message: 'Register berhasil.',
      ...this.createAuthResponse(user),
    };
  }

  async login(dto: LoginDto) {
    const identifier = (dto.identifier ?? dto.email ?? '').trim().toLowerCase();
    if (!identifier) {
      throw new BadRequestException('Identifier atau email wajib diisi.');
    }

    const user = await this.userModel.findOne({
      $or: [{ email: identifier }, { username: identifier }],
    });

    if (!user || !user.password) {
      throw new UnauthorizedException('Akun tidak ditemukan.');
    }

    const isPasswordValid = await bcrypt.compare(dto.password, user.password);
    if (!isPasswordValid) {
      throw new UnauthorizedException('Password salah.');
    }

    return {
      message: 'Login berhasil.',
      ...this.createAuthResponse(user),
    };
  }

  async loginWithGoogle(dto: GoogleAuthDto) {
    const email = (dto.email ?? '').trim().toLowerCase();
    if (!email) {
      throw new BadRequestException('Email Google wajib diisi.');
    }

    let user = await this.userModel.findOne({ email });
    if (!user) {
      const baseUsername =
        (dto.displayName?.trim() || email.split('@')[0] || 'user')
          .replace(/\s+/g, '_')
          .toLowerCase();
      const existingUsername = await this.userModel.findOne({
        username: baseUsername,
      });
      const username = existingUsername ? `${baseUsername}_${Date.now()}` : baseUsername;

      user = await this.userModel.create({
        username,
        email,
        provider: 'google',
        photoUrl: dto.photoUrl?.trim(),
      });
    } else {
      user.provider = user.provider ?? 'google';
      if (dto.photoUrl?.trim()) {
        user.photoUrl = dto.photoUrl.trim();
      }
      await user.save();
    }

    return {
      message: 'Login Google berhasil.',
      ...this.createAuthResponse(user),
    };
  }

  async setPin(dto: SetPinDto) {
    const identifier = dto.identifier.trim().toLowerCase();
    const user = await this.userModel.findOne({
      $or: [{ email: identifier }, { username: identifier }],
    });

    if (!user) {
      throw new NotFoundException('User tidak ditemukan.');
    }

    user.pin = dto.pin;
    await user.save();

    return { message: 'PIN berhasil disimpan.' };
  }

  async verifyPin(dto: VerifyPinDto) {
    const identifier = dto.identifier.trim().toLowerCase();
    const user = await this.userModel.findOne({
      $or: [{ email: identifier }, { username: identifier }],
    });

    if (!user) {
      throw new NotFoundException('User tidak ditemukan.');
    }

    if (!user.pin) {
      throw new BadRequestException('PIN belum diatur.');
    }

    if (user.pin !== dto.pin) {
      throw new UnauthorizedException('PIN salah.');
    }

    return { message: 'PIN valid.' };
  }

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