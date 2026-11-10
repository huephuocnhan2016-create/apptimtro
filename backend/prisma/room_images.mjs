// Gan anh phong mau vao danh sach phong tro.
//
// Anh goc nam trong prisma/assets/room-images (duoc track), duoc copy sang
// backend/uploads/ - noi main.ts phuc tinh qua duong dan /uploads. Trong DB
// chi luu duong dan tuong doi "/uploads/<ten>", ung dung tu ghep vao goc cua
// API_BASE_URL, nen doi cong 3000 -> 3300 hay len ten mien that van dung.
//
// Chay rieng tren DB huu tai (khong xoa gi):  node prisma/attach-room-images.mjs
// Seed moi cung goi ham nay sau khi tao phong.
import { copyFile, mkdir, stat } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ASSET_DIR = fileURLToPath(new URL('./assets/room-images/', import.meta.url));

// Gia phong quyet dinh chiec anh nao hop ly: phong tre tien nhieu thi khong
// nen dung anh studio cao cap. "hero" la anh phong ngoai that, luong tu o
// dung dau danh sach de anh bia khong bao gio la nha ve sinh hay khu nau.
const BANDS = [
  {
    below: 2_000_000,
    hero: ['room-budget-01', 'room-budget-02'],
    detail: ['room-budget-03'],
  },
  {
    below: 3_500_000,
    hero: ['room-mid-01'],
    detail: ['room-mid-02', 'room-mid-03'],
  },
  {
    below: Infinity,
    hero: ['room-premium-01', 'room-premium-02'],
    detail: ['room-mid-01'],
  },
];

function bandFor(price) {
  return BANDS.find((band) => price < band.below) ?? BANDS.at(-1);
}

// Lech theo so thu tu phong de hai phong canh nhau khong trung anh bia.
function coverOrder(band, index) {
  const total = band.hero.length + band.detail.length;
  const count = 1 + (index % total);
  const start = index % band.hero.length;
  const names = [];
  for (let slot = 0; slot < count; slot += 1) {
    names.push(
      slot < band.hero.length
        ? band.hero[(start + slot) % band.hero.length]
        : band.detail[slot - band.hero.length],
    );
  }
  return names;
}

async function publishAssets(uploadDir) {
  await mkdir(uploadDir, { recursive: true });
  const names = [
    ...new Set(BANDS.flatMap((band) => [...band.hero, ...band.detail])),
  ];
  for (const name of names) {
    const source = join(ASSET_DIR, `${name}.png`);
    const target = join(uploadDir, `${name}.png`);
    const [from, to] = await Promise.all([
      stat(source),
      stat(target).catch(() => null),
    ]);
    if (to?.size === from.size) continue;
    await copyFile(source, target);
  }
  return names;
}

// Chay lai duoc: xoa anh mau cua chinh script nay roi gan lai theo phong.
// Anh chu tro tu tai len (ten la uuid) khong bi dong toi.
export async function attachRoomImages(prisma, uploadDir = join(process.cwd(), 'uploads')) {
  const assets = await publishAssets(uploadDir);
  await prisma.roomImage.deleteMany({
    where: { imageUrl: { startsWith: '/uploads/room-' } },
  });
  const rooms = await prisma.room.findMany({
    select: { id: true, price: true },
    // Thu tu on dinh de lan chay lai khong dao anh bia cua phong nao.
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
  });

  const rows = [];
  rooms.forEach((entry, index) => {
    coverOrder(bandFor(Number(entry.price)), index).forEach((file, slot) => {
      rows.push({ roomId: entry.id, imageUrl: `/uploads/${file}.png`, sortOrder: slot });
    });
  });

  if (rows.length > 0) {
    await prisma.roomImage.createMany({ data: rows });
  }
  return { assets: assets.length, rooms: rooms.length, images: rows.length };
}
