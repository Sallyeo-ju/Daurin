import {
  BadRequestException,
  ConflictException,
  InternalServerErrorException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import axios from 'axios';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { VerifyPinDto } from './dto/verify-pin.dto';
import { User, UserDocument } from './schemas/user.schema';

@Injectable()
export class AuthService {
  constructor(
    @InjectModel(User.name)
    private readonly userModel: Model<UserDocument>,
  ) {}

  async googleLogin(dto: { idToken: string; email?: string; displayName?: string; photoUrl?: string; }) {
    try {
      if (!dto.idToken) {
        throw new BadRequestException('idToken is required');
      }

      // Verify token with Google's tokeninfo endpoint
      const verifyResp = await axios.get(
        `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(dto.idToken)}`,
      );

      const tokenInfo = verifyResp.data as any;
      const email = (tokenInfo.email || dto.email || '').toString().trim().toLowerCase();
      const displayName = dto.displayName ?? tokenInfo.name ?? '';
      const photoUrl = dto.photoUrl ?? tokenInfo.picture ?? '';

      if (!email) {
        throw new BadRequestException('Verified token does not contain email');
      }

      // Upsert user by email
      let user = await this.userModel.findOne({ email }).exec();
      if (user) {
        // update fields if necessary
        const update: any = {};
        if (photoUrl && user.photoUrl !== photoUrl) update.photoUrl = photoUrl;
        if (!user.provider) update.provider = 'google';
        if (Object.keys(update).length > 0) {
          await this.userModel.updateOne({ _id: user._id }, { $set: update }).exec();
          user = await this.userModel.findById(user._id).exec();
        }
      } else {
        // create a safe username from displayName or email localpart
        let baseUsername = displayName.trim().toLowerCase().replace(/[^a-z0-9]+/g, '_');
        if (!baseUsername || baseUsername.length === 0) {
          baseUsername = (email.split('@')[0] || '').replace(/[^a-z0-9]+/g, '_');
        }
        let usernameCandidate = baseUsername;
        let suffix = 0;
        while (await this.userModel.findOne({ username: usernameCandidate }).exec()) {
          suffix += 1;
          usernameCandidate = `${baseUsername}_${suffix}`;
        }

        const newUser = await this.userModel.create({
          username: usernameCandidate,
          email,
          provider: 'google',
          photoUrl,
        } as any);
        user = newUser;
      }

      if (!user) {
        throw new InternalServerErrorException('User creation failed');
      }

      return {
        message: 'Login successful',
        user: {
          id: (user as any)._id,
          username: (user as any).username,
          email: (user as any).email,
          photoUrl: (user as any).photoUrl,
        },
      };
    } catch (error) {
      if (axios.isAxiosError(error) && error.response) {
        throw new InternalServerErrorException('Failed to verify token with Google');
      }
      throw this.mapDbError(error);
    }
  }

  async register(registerDto: RegisterDto) {
    try {
      const normalizedEmail = registerDto.email.trim().toLowerCase();
      const normalizedUsername = registerDto.username.trim().toLowerCase();

      const existingUser = await this.userModel
        .findOne({
          $or: [{ email: normalizedEmail }, { username: normalizedUsername }],
        })
        .exec();

      if (existingUser) {
        if (existingUser.email === normalizedEmail) {
          throw new ConflictException('Email already registered');
        }
        throw new ConflictException('Username already taken');
      }

      const user = await this.userModel.create({
        ...registerDto,
        email: normalizedEmail,
        username: normalizedUsername,
        pin: registerDto.pin,
      });

      return {
        message: 'Registration successful',
        user: {
          id: user._id,
          username: user.username,
          email: user.email,
          phoneNumber: user.phoneNumber,
        },
      };
    } catch (error) {
      throw this.mapDbError(error);
    }
  }

  async login(loginDto: LoginDto) {
    try {
      const rawIdentifier = loginDto.identifier ?? loginDto.email;
      if (!rawIdentifier || rawIdentifier.trim() === '') {
        throw new BadRequestException('identifier or email is required');
      }

      const normalizedIdentifier = rawIdentifier.trim().toLowerCase();

      const user = await this.userModel
        .findOne({
          $or: [
            { email: normalizedIdentifier },
            { username: normalizedIdentifier },
          ],
        })
        .exec();

      if (!user) {
        throw new NotFoundException(
          'Account not found. Please register first (email/username).',
        );
      }

      if (user.password !== loginDto.password) {
        throw new UnauthorizedException('Wrong password');
      }

      return {
        message: 'Login successful',
        user: {
          id: user._id,
          username: user.username,
          email: user.email,
          phoneNumber: user.phoneNumber,
        },
      };
    } catch (error) {
      throw this.mapDbError(error);
    }
  }

  async verifyPin(verifyPinDto: VerifyPinDto) {
    try {
      const normalizedIdentifier = verifyPinDto.identifier.trim().toLowerCase();
      const user = await this.userModel
        .findOne({
          $or: [
            { email: normalizedIdentifier },
            { username: normalizedIdentifier },
          ],
        })
        .exec();

      if (!user) {
        throw new NotFoundException('Account not found');
      }

      if (user.pin !== verifyPinDto.pin) {
        throw new UnauthorizedException('Wrong PIN');
      }

      return {
        message: 'PIN verified',
        verified: true,
      };
    } catch (error) {
      throw this.mapDbError(error);
    }
  }

  async setPin(dto: { identifier: string; pin: string }) {
    try {
      const normalizedIdentifier = dto.identifier.trim().toLowerCase();
      const user = await this.userModel
        .findOne({
          $or: [{ email: normalizedIdentifier }, { username: normalizedIdentifier }],
        })
        .exec();

      if (!user) {
        throw new NotFoundException('Account not found');
      }

      user.pin = dto.pin;
      await user.save();

      return { message: 'PIN set' };
    } catch (error) {
      throw this.mapDbError(error);
    }
  }

  private mapDbError(error: unknown) {
    if (
      error instanceof BadRequestException ||
      error instanceof ConflictException ||
      error instanceof NotFoundException ||
      error instanceof UnauthorizedException
    ) {
      return error;
    }

    if (error instanceof Error) {
      const message = error.message.toLowerCase();
      if (
        message.includes('buffering timed out') ||
        message.includes('server selection timed out') ||
        message.includes('topology is closed') ||
        message.includes('econnrefused')
      ) {
        return new ServiceUnavailableException(
          'Database unavailable. Pastikan MongoDB berjalan.',
        );
      }
    }

    return new InternalServerErrorException('Internal server error');
  }
}
