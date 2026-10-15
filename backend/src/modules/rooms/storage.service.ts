import { Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { mkdir, unlink, writeFile } from 'fs/promises';
import { join } from 'path';

export const STORAGE_SERVICE = Symbol('STORAGE_SERVICE');

export interface RoomImageUpload {
  mimetype: string;
  buffer: Buffer;
}

export interface StorageService {
  store(file: RoomImageUpload): Promise<string>;
  remove(url: string): Promise<void>;
}

@Injectable()
export class LocalStorageService implements StorageService {
  private readonly directory = join(process.cwd(), 'uploads');

  async store(file: RoomImageUpload): Promise<string> {
    await mkdir(this.directory, { recursive: true });
    const extension = file.mimetype === 'image/png' ? 'png' :
      file.mimetype === 'image/webp' ? 'webp' :
      file.mimetype === 'image/gif' ? 'gif' : 'jpg';
    const name = `${randomUUID()}.${extension}`;
    await writeFile(join(this.directory, name), file.buffer, { flag: 'wx' });
    const baseUrl = process.env.PUBLIC_API_URL ?? 'http://localhost:3000';
    return `${baseUrl.replace(/\/$/, '')}/uploads/${name}`;
  }

  async remove(url: string): Promise<void> {
    const parsed = new URL(url);
    if (!parsed.pathname.startsWith('/uploads/')) return;
    const name = parsed.pathname.slice('/uploads/'.length);
    if (!/^[0-9a-f-]+\.(png|webp|gif|jpg)$/.test(name)) return;
    await unlink(join(this.directory, name));
  }
}
