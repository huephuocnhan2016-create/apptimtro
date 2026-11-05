// Chon mau don vi hanh chinh cap xa/phuong trai khap VN tu du lieu OSM.
// Can 2 file trong tools/.cache: vn_districts.json, vn_province_membership.json
//   (vn_districts.json: relation admin_level=6 + center)
//   (vn_province_membership.json: commune relation id -> ten tinh, tu relation cha)
// Dung: node tools/select_communes.mjs [soDonViMotMien|soDonVi] [nghiengTenTinh]
//   node tools/select_communes.mjs 20              -> 60 don vi, 20 moi mien
//   node tools/select_communes.mjs 40 "Hồ Chí Minh" -> 40 don vi rieng TP.HCM
// Ket qua: backend/prisma/data/vn_communes_sample.json (file commit duoc, seed doc truc tiep)
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';

const PER_REGION = Number(process.argv[2] ?? 20);
const PROVINCE_FILTER = process.argv[3] ?? null;
const NORTHERN = ['Hà Nội', 'Bắc Ninh', 'Hưng Yên', 'Hải Phòng', 'Ninh Bình', 'Quảng Ninh',
  'Phú Thọ', 'Thái Nguyên', 'Lạng Sơn', 'Cao Bằng', 'Tuyên Quang', 'Lào Cai', 'Điện Biên',
  'Lai Châu', 'Sơn La'];
const CENTRAL = ['Thanh Hóa', 'Nghệ An', 'Hà Tĩnh', 'Quảng Trị', 'Huế', 'Đà Nẵng', 'Quảng Ngãi',
  'Gia Lai', 'Đắk Lắk', 'Khánh Hòa', 'Lâm Đồng'];
const GRID_STEPS = [0.6, 0.45, 0.35, 0.25, 0.18, 0.12, 0.08, 0.05];

const districts = JSON.parse(
  readFileSync(new URL('./.cache/vn_districts.json', import.meta.url), 'utf8'),
).elements;
const membership = JSON.parse(
  readFileSync(new URL('./.cache/vn_province_membership.json', import.meta.url), 'utf8'),
);

function regionOf(province) {
  const short = province.replace(/^(Tỉnh|Thành phố)\s+/i, '');
  if (NORTHERN.includes(short)) return 'BAC';
  if (CENTRAL.includes(short)) return 'TRUNG';
  return 'NAM';
}

const communes = [];
let skippedIslands = 0;
let skippedUnmapped = 0;
for (const element of districts) {
  const name = element.tags?.name;
  if (!name || !element.center) continue;
  const province = membership[String(element.id)];
  if (!province) { skippedUnmapped += 1; continue; }
  if (PROVINCE_FILTER && !province.includes(PROVINCE_FILTER)) continue;
  if (name.startsWith('Đặc khu')) { skippedIslands += 1; continue; }
  communes.push({
    id: element.id,
    name,
    province,
    region: regionOf(province),
    lat: element.center.lat,
    lon: element.center.lon,
  });
}
console.log(`Xac dinh duoc ${communes.length} xa/phuong` +
  `${PROVINCE_FILTER ? ` mang "${PROVINCE_FILTER}"` : ' thuoc 3 mien'} ` +
  `(bo ${skippedIslands} dao/dac khu, ${skippedUnmapped} chua co quan he cha).`);

// Trong 1 mien: lay luân phiên theo tung tinh, moi tinh chon theo luoi kinh/vi do
// de phong trai deu ca nuoc chu khong dum mot do thi.
// `taken` dung chung de khong bao gio chon lap lai cung 1 don vi.
function spreadWithin(list, count, taken) {
  const picked = [];
  for (const step of GRID_STEPS) {
    const cells = new Set();
    for (const c of list) {
      if (picked.length >= count) break;
      if (taken.has(c.id)) continue;
      const key = `${Math.floor(c.lat / step)}:${Math.floor(c.lon / step)}`;
      if (cells.has(key)) continue;
      cells.add(key);
      taken.add(c.id);
      picked.push(c);
    }
    if (picked.length >= count) break;
  }
  return picked;
}

function sampleByRegion(list, quota, taken) {
  const provinces = new Map();
  for (const c of list) {
    const bucket = provinces.get(c.province) ?? [];
    bucket.push(c);
    provinces.set(c.province, bucket);
  }
  const perProvince = Math.max(1, Math.floor(quota / provinces.size));
  const chosen = new Map();
  for (const [province, bucket] of provinces) {
    chosen.set(province, spreadWithin(bucket, perProvince + 1, taken));
  }
  const picked = [];
  let round = 0;
  while (picked.length < quota && round < perProvince + 1) {
    for (const bucket of chosen.values()) {
      if (picked.length >= quota) break;
      if (bucket[round]) picked.push(bucket[round]);
    }
    round += 1;
  }
  return picked;
}

let selected;
if (PROVINCE_FILTER) {
  const taken = new Set();
  selected = spreadWithin(communes, PER_REGION, taken);
  console.log(`  ${PROVINCE_FILTER}: ${communes.length} don vi -> chon ${selected.length}`);
} else {
  const byRegion = { BAC: [], TRUNG: [], NAM: [] };
  for (const c of communes) byRegion[c.region].push(c);
  const taken = new Set();
  selected = ['BAC', 'TRUNG', 'NAM'].flatMap((region) => {
    const picked = sampleByRegion(byRegion[region], PER_REGION, taken);
    console.log(`  ${region}: ${byRegion[region].length} don vi -> chon ${picked.length} ` +
      `(${new Set(picked.map((c) => c.province)).size} tinh/thanh)`);
    return picked;
  });
}

const samplePath = new URL('../backend/prisma/data/vn_communes_sample.json', import.meta.url);
mkdirSync(new URL('../backend/prisma/data', import.meta.url), { recursive: true });
writeFileSync(samplePath, JSON.stringify(selected, null, 1));
const covered = [...new Set(selected.map((c) => c.province))];
console.log(`\nDa chon ${selected.length} don vi thuoc ${covered.length}/${new Set(communes.map((c) => c.province)).size} tinh/thanh:`);
console.log('  ' + covered.join(', '));
console.log(`-> ${samplePath.pathname}`);
