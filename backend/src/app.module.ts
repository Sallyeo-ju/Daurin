import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { MongooseModule } from '@nestjs/mongoose';
import { join } from 'path';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { ItemsModule } from './items/items.module';
import { CartModule } from './cart/cart.module';
import { ChatModule } from './chat/chat.module';
import { TransactionsModule } from './transactions/transactions.module';

function sanitizeMongoUri(uri: string): string {
  const authMatch = uri.match(
    /^(mongodb(?:\+srv)?):\/\/([^@/]+)@([^?]+)(?:\?(.*))?$/,
  );

  if (!authMatch) {
    return uri;
  }

  const [, scheme, auth, hostAndPath] = authMatch;
  let queryString = authMatch[4] ?? '';
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
      queryString = '';
    }
  }

  return `${scheme}://${username}:${encodeURIComponent(password)}@${host}${path}${queryString ? `?${queryString}` : ''}`;
}

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: join(__dirname, '..', '.env'),
    }),
    MongooseModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        uri: (() => {
          const mongoUri = configService.get<string>('MONGODB_URI')?.trim();

          if (!mongoUri) {
            throw new Error(
              'MONGODB_URI is missing. Set it in Railway Variables for the production service.',
            );
          }

          return sanitizeMongoUri(mongoUri);
        })(),
        // Increase timeouts to allow for slower network / SRV resolution
        serverSelectionTimeoutMS: 20000,
        connectTimeoutMS: 20000,
        socketTimeoutMS: 30000,
        bufferCommands: false,
      }),
    }),
    AuthModule,
    ItemsModule,
    CartModule,
    ChatModule,
    TransactionsModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule { }
