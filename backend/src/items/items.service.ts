import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { CreateItemDto } from './dto/create-item.dto';
import { UpdateItemDto } from './dto/update-item.dto';
import { Item, ItemDocument } from './schemas/item.schema';

@Injectable()
export class ItemsService {
  constructor(
    @InjectModel(Item.name)
    private readonly itemModel: Model<ItemDocument>,
  ) { }

  create(createItemDto: CreateItemDto) {
    return this.itemModel.create(createItemDto);
  }

  findAll() {
    return this.itemModel.find().exec();
  }

  async findOne(id: string) {
    const item = await this.itemModel.findById(id).exec();
    if (!item) {
      throw new NotFoundException(`Item with id ${id} not found`);
    }
    return item;
  }

  async update(id: string, updateItemDto: UpdateItemDto) {
    const item = await this.itemModel
      .findByIdAndUpdate(id, updateItemDto, { new: true, runValidators: true })
      .exec();

    if (!item) {
      throw new NotFoundException(`Item with id ${id} not found`);
    }

    return item;
  }

  async remove(id: string) {
    const item = await this.itemModel.findByIdAndDelete(id).exec();
    if (!item) {
      throw new NotFoundException(`Item with id ${id} not found`);
    }
    return { message: 'Item deleted successfully' };
  }
}
