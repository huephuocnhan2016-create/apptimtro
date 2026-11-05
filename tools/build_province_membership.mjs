// Map quan he cha-con OSM: 3319 don vi cap xa -> 1 trong 34 tinh/thanh.
// Mot truy vấn duy nhat tra ve ca 34 relation cap 4 kem danh sach member (role subarea).
// Dau ra: tools/.cache/vn_province_membership.json = { "<communeRelationId>": "<Ten Tinh>" }
import { readFileSync, writeFileSync } from 'node:fs';

const ENDPOINTS = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
  'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
];
const UA = 'TroTot-seed/1.0 (dev data generation)';
const OUT = new URL('./.cache/vn_province_membership.json', import.meta.url);

const provinces = JSON.parse(
  readFileSync(new URL('./.cache/vn_provinces.json', import.meta.url), 'utf8'),
).elements.map((e) => ({ id: e.id, name: e.tags.name }));

const data = `[out:json][timeout:180];rel(id:${provinces.map((p) => p.id).join(',')});out body;`;

async function run() {
  let lastError;
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const endpoint = ENDPOINTS[attempt % ENDPOINTS.length];
    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'User-Agent': UA, 'Content-Type': 'application/x-www-form-urlencoded' },
        body: `data=${encodeURIComponent(data)}`,
        signal: AbortSignal.timeout(190_000),
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const json = await response.json();
      if (!Array.isArray(json.elements) || json.elements.length < 30) {
        throw new Error(`So relation tra ve = ${json.elements?.length ?? 0}, duoi 30`);
      }
      return json;
    } catch (error) {
      lastError = error;
      console.log(`  ${endpoint.replace('https://', '').split('/')[0]}: ${error.message}`);
      await new Promise((resolve) => setTimeout(resolve, 4_000 * (attempt + 1)));
    }
  }
  throw lastError;
}

console.log(`Gui 1 truy van cho ${provinces.length} relation cap tinh...`);
const result = await run();

const membership = {};
for (const element of result.elements) {
  const subareas = (element.members ?? []).filter((m) => m.type === 'relation');
  for (const member of subareas) membership[String(member.ref)] = element.tags.name;
  console.log(`  ${element.tags.name}: ${subareas.length} xa/phuong (role: ` +
    `${[...new Set(subareas.map((m) => m.role || '-'))].join(', ')})`);
}

writeFileSync(OUT, JSON.stringify(membership));
console.log(`\nMap ${Object.keys(membership).length} don vi cap xa -> ${OUT.pathname}`);
