// Bo sung anh cho phong tro dang ton tai trong DB, khong xoa hay seed lai gi.
// Chay:  node prisma/attach-room-images.mjs
import { PrismaClient } from '@prisma/client';
import { attachRoomImages } from './room_images.mjs';

const prisma = new PrismaClient();

attachRoomImages(prisma)
  .then((result) => {
    console.log(
      `Anh mau: ${result.assets} | phong duoc gan: ${result.rooms} | ` +
      `dong room_images: ${result.images}`,
    );
  })
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
