import { Body, Controller, Get, InternalServerErrorException, Post } from '@nestjs/common';
import axios from 'axios';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getHello() {
    return this.appService.getHello();
  }

  @Post('api/cek-ongkir')
  async cekOngkir(@Body() body: { origin?: string; destination?: string; weight?: number }) {
    try {
      const formBody = new URLSearchParams();
      formBody.set('origin', body.origin?.toString() ?? '');
      formBody.set('destination', body.destination?.toString() ?? '');
      formBody.set('weight', body.weight?.toString() ?? '0');
      formBody.set('courier', 'jne');
      formBody.set('price', 'lowest');

      const response = await axios.post(
        'https://rajaongkir.komerce.id/api/v1/calculate/domestic-cost',
        formBody.toString(),
        {
          headers: {
            key: process.env.KOMERCE_API_KEY ?? '',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        },
      );

      const payload = response.data as Record<string, unknown>;
      const cost = this.extractCost(payload);

      return {
        success: true,
        cost,
        data: payload,
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      throw new InternalServerErrorException(
        `Gagal mengambil data ongkos kirim: ${message}`,
      );
    }
  }

  private extractCost(value: unknown): number {
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value;
    }

    if (Array.isArray(value)) {
      for (const item of value) {
        const found = this.extractCost(item);
        if (found > 0) {
          return found;
        }
      }
      return 0;
    }

    if (value && typeof value === 'object') {
      const record = value as Record<string, unknown>;
      const directCost = record.cost;
      if (typeof directCost === 'number' && Number.isFinite(directCost)) {
        return directCost;
      }

      const nestedCost = record.data;
      if (nestedCost !== undefined) {
        const found = this.extractCost(nestedCost);
        if (found > 0) {
          return found;
        }
      }

      for (const nestedValue of Object.values(record)) {
        const found = this.extractCost(nestedValue);
        if (found > 0) {
          return found;
        }
      }
    }

    return 0;
  }
}
