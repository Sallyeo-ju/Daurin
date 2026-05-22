import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { MongooseModule } from '@nestjs/mongoose';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { ItemsModule } from './items/items.module';
import { CartModule } from './cart/cart.module';

function sanitizeMongoUri(uri: string): string {
  const authMatch = uri.match(
    /^(mongodb(?:\+srv)?):\/\/([^@/]+)@([^?]+)(?:\?(.*))?$/,
  );

  if (!authMatch) {
    return uri;
  }

  const [, scheme, auth, hostAndPath, queryString] = authMatch;
  const separatorIndex = auth.indexOf(':');

  if (separatorIndex < 0) {
    return uri;
  }

  const username = auth.slice(0, separatorIndex);
  const password = auth.slice(separatorIndex + 1).replace(/^:/, '');
  const slashIndex = hostAndPath.indexOf('/');
  const host = slashIndex >= 0 ? hostAndPath.slice(0, slashIndex) : hostAndPath;
  let path = slashIndex >= 0 ? hostAndPath.slice(slashIndex) : '';

  if ((!path || path === '/') && queryString) {
    const searchParams = new URLSearchParams(queryString);
    const entries = [...searchParams.entries()];

    if (entries.length === 1) {
      const [databaseName] = entries[0];
      path = `/${databaseName}`;
    }
  }

  return `${scheme}://${username}:${encodeURIComponent(password)}@${host}${path}`;
}

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    MongooseModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        uri: sanitizeMongoUri(
          configService.get<string>('MONGODB_URI') ??
          'mongodb://localhost:27017/daurin',
        ),
        // Fail fast when MongoDB is unavailable to avoid hanging HTTP requests.
        serverSelectionTimeoutMS: 5000,
        connectTimeoutMS: 5000,
        socketTimeoutMS: 10000,
        bufferCommands: false,
      }),
    }),
    AuthModule,
    ItemsModule,
    CartModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule { }
