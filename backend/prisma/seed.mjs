// Seed du lieu phong tro that theo don vi hanh chinh cap xa/phuong (OSM, hieu luc sau 1/7/2025).
// Nguon mau: prisma/data/vn_communes_sample.json (tai tao bang: node tools/select_communes.mjs).
// XOA TOAN BO du lieu cu roi tao lai: 1 chu tro TP.HCM + 2-3 phong moi xa/phuong du chon.
// Chay:  npx prisma db seed
import { readFileSync, existsSync } from 'node:fs';
import { PrismaClient, RoomStatus, UserRole } from '@prisma/client';

const SEED = 20261105;
const SOURCE = new URL('./data/vn_communes_sample.json', import.meta.url);
const PRICE_BAND = { BAC: 1_200_000, TRUNG: 1_000_000, NAM: 1_100_000 };
const BIG_CITY = ['Hà Nội', 'Hồ Chí Minh'];
const METRO = ['Đà Nẵng', 'Hải Phòng', 'Cần Thơ', 'Huế', 'Đồng Nai', 'Bắc Ninh', 'Thái Nguyên',
  'Quảng Ninh', 'Khánh Hòa', 'Lâm Đồng', 'Nghệ An'];
const AMENITIES = ['Wifi', 'Điều hòa', 'Nước nóng', 'Máy giặt', 'Chỗ để xe', 'Giờ tự do',
  'Thang máy', 'Khu nấu ăn', 'Camera an ninh', 'Ban công', 'Nhà vệ sinh khép kín',
  'Gần trường đại học', 'Gần khu công nghiệp'];

const prisma = new PrismaClient();

function random(seed) {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function shortProvince(province) {
  return province.replace(/^(Tỉnh|Thành phố)\s+/i, '');
}

function shortCommune(name) {
  return name.replace(/^(Phường|Xã|Thị trấn)\s+/i, '');
}

function priceFor(region, province, rand) {
  const short = shortProvince(province);
  const ceiling = BIG_CITY.includes(short) ? 5_500_000
    : METRO.includes(short) ? 3_600_000
      : 2_400_000;
  const raw = PRICE_BAND[region] + rand() * (ceiling - PRICE_BAND[region]);
  return Math.round(raw / 100_000) * 100_000;
}

function roomData(commune, landlordId, rand, variant) {
  const { region, province } = commune;
  const price = priceFor(region, province, rand);
  const totalRooms = 6 + Math.floor(rand() * 25);
  const availableRooms = rand() < 0.12 ? 0 : 1 + Math.floor(rand() * (totalRooms - 1));
  const area = Math.round(15 + rand() * 20);
  const amenityCount = 3 + Math.floor(rand() * 4);
  const amenities = AMENITIES.slice().sort(() => rand() - 0.5).slice(0, amenityCount);
  const createdAt = new Date(Date.now() - Math.floor(rand() * 45) * 86_400_000);
  // Phong cùng xa le nhau ~300 m de marker tren ban do khong chong len nhau.
  const jitter = variant === 0 ? 0 : (rand() - 0.5) * 0.006;
  const jitter2 = variant === 0 ? 0 : (rand() - 0.5) * 0.006;
  return {
    landlordId,
    title: (`Phòng trọ ${shortCommune(commune.name)}` +
      `${variant > 0 ? ` - cơ sở ${variant + 1}` : ''}`).slice(0, 160),
    description:
      `Phòng trọ tại ${commune.name}, ${shortProvince(province)}. Diện tích ${area} m², ` +
      `tiện ích: ${amenities.join(', ').toLowerCase()}. Vào ở ngay, hợp đồng tối thiểu 6 tháng, ` +
      `điện ${3_000 + Math.round(rand() * 10) * 100} đ/số, nước ${150_000 + Math.round(rand() * 15) * 10_000} đ/người/tháng.`,
    address: `${commune.name}, ${province}`,
    latitude: Number((commune.lat + jitter).toFixed(6)),
    longitude: Number((commune.lon + jitter2).toFixed(6)),
    price,
    area,
    totalRooms,
    availableRooms,
    electricityPrice: 3_000 + Math.round(rand() * 10) * 100,
    waterPrice: 150_000 + Math.round(rand() * 15) * 10_000,
    internetPrice: 100_000 + Math.round(rand() * 10) * 10_000,
    deposit: price * (rand() < 0.5 ? 1 : 2),
    status: availableRooms > 0 ? RoomStatus.AVAILABLE : RoomStatus.FULL,
    amenities,
    createdAt,
    updatedAt: createdAt,
  };
}

async function main() {
  if (!existsSync(SOURCE)) {
    throw new Error('Thieu prisma/data/vn_communes_sample.json. Chay: node tools/select_communes.mjs');
  }
  const communes = JSON.parse(readFileSync(SOURCE, 'utf8'));
  const rand = random(SEED);

  console.log(`Xoa toan bo du lieu cu (${communes.length} don vi se du dung)...`);
  await prisma.$executeRawUnsafe(
    'TRUNCATE TABLE "users", "rooms", "room_images", "favorites", ' +
    '"refresh_tokens", "phone_verifications" RESTART IDENTITY CASCADE',
  );

  const landlord = await prisma.user.create({
    data: {
      phone: '+84908000001',
      email: 'chu-tro-hcm@trotot.test',
      fullName: 'Chủ trọ TP.HCM',
      role: UserRole.LANDLORD,
      isVerified: true,
    },
  });

  const rooms = [];
  for (const [index, commune] of communes.entries()) {
    const variants = 2 + (index % 2);
    for (let variant = 0; variant < variants; variant += 1) {
      rooms.push(roomData(commune, landlord.id, rand, variant));
    }
  }

  console.log(`Tao ${rooms.length} phong cho ${landlord.fullName} (${landlord.phone})...`);
  await prisma.room.createMany({ data: rooms });

  const summary = await prisma.$queryRaw`
    SELECT u."full_name" AS "chu tro",
           count(r.id)::int AS phong,
           count(DISTINCT split_part(r.address, ', ', 2))::int AS "tinh/thanh",
           count(DISTINCT r.address)::int AS "xa/phuong",
           coalesce(min(r.price), 0)::bigint AS "gia tu",
           coalesce(max(r.price), 0)::bigint AS "gia den",
           sum(r.available_rooms)::int AS "phong trong",
           min(r."latitude")::numeric AS "nam nhat",
           max(r."latitude")::numeric AS "bac nhat"
      FROM "users" u LEFT JOIN "rooms" r ON r."landlord_id" = u.id
     WHERE u.role = 'LANDLORD'
     GROUP BY u."full_name"
     ORDER BY u."full_name"`;
  console.table(summary);
  console.log('Theo trang thai:', await prisma.room.groupBy({
    by: ['status'], _count: { _all: true },
  }));
  console.log('Thieu toa do/location:', await prisma.$queryRaw`
    SELECT count(*)::int AS n FROM "rooms" WHERE "latitude" IS NULL OR "location" IS NULL`);
  console.log('So tai khoan:', await prisma.user.count(),
    '| so yeu thich:', await prisma.favorite.count());
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
