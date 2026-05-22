import {
  Body,
  Controller,
  Delete,
  Get,
  UploadedFile,
  UseInterceptors,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { existsSync, mkdirSync } from 'fs';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { CreateItemDto } from './dto/create-item.dto';
import { ItemsService } from './items.service';
import { UpdateItemDto } from './dto/update-item.dto';

const uploadsDir = join(process.cwd(), 'uploads');

function ensureUploadsDir() {
  if (!existsSync(uploadsDir)) {
    mkdirSync(uploadsDir, { recursive: true });
  }
}

function imageFilename(
  _: unknown,
  file: { originalname: string },
  cb: (error: Error | null, filename: string) => void,
) {
  const suffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
  cb(null, `${suffix}${extname(file.originalname)}`);
}

@Controller('items')
export class ItemsController {
  constructor(private readonly itemsService: ItemsService) { }

  @Post()
  @UseInterceptors(
    FileInterceptor('photo', {
      storage: diskStorage({
        destination: (
          _req: unknown,
          _file: unknown,
          cb: (error: Error | null, destination: string) => void,
        ) => {
          ensureUploadsDir();
          cb(null, uploadsDir);
        },
        filename: imageFilename,
      }),
      fileFilter: (
        _req: unknown,
        file: { mimetype: string; originalname: string },
        cb: (error: Error | null, acceptFile: boolean) => void,
      ) => {
        // Mobile gallery providers may send non-standard mime types.
        // Accept the file and let downstream processing handle invalid content.
        cb(null, true);
      },
      limits: { fileSize: 5 * 1024 * 1024 },
    }),
  )
  create(@Body() createItemDto: CreateItemDto, @UploadedFile() photo?: any) {
    const discountPercent = createItemDto.discountPercent ?? 0;
    const discountedPrice =
      discountPercent > 0
        ? Math.max(
            0,
            Math.round(createItemDto.price * (100 - discountPercent) / 100),
          )
        : undefined;

    const payload: CreateItemDto = {
      ...createItemDto,
      isPromoted: discountPercent > 0,
      discountedPrice,
      promoNote:
        discountPercent > 0 ? `Diskon ${discountPercent}%` : undefined,
      imageUrl: photo?.filename ? `/uploads/${photo.filename}` : undefined,
    };

    return this.itemsService.create(payload);
  }

  @Get()
  findAll() {
    return this.itemsService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.itemsService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() updateItemDto: UpdateItemDto) {
    return this.itemsService.update(id, updateItemDto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.itemsService.remove(id);
  }
}
