import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface Coordinates {
  latitude: number;
  longitude: number;
}

interface NominatimResult {
  lat: string;
  lon: string;
}

@Injectable()
export class GeocodingService {
  private nextRequestAt = 0;
  private queue: Promise<void> = Promise.resolve();

  constructor(private readonly config: ConfigService) {}

  geocode(address: string): Promise<Coordinates | null> {
    const result = this.queue.then(async () => {
      const wait = Math.max(0, this.nextRequestAt - Date.now());
      if (wait > 0) {
        await new Promise((resolve) => setTimeout(resolve, wait));
      }
      this.nextRequestAt = Date.now() + 1_000;
      return this.lookup(address);
    });
    this.queue = result.then(() => undefined, () => undefined);
    return result;
  }

  private async lookup(address: string): Promise<Coordinates | null> {
    const query = new URLSearchParams({
      addressdetails: '0',
      countrycodes: 'vn',
      format: 'jsonv2',
      limit: '1',
      q: /việt nam|vietnam/i.test(address) ? address : `${address}, Việt Nam`,
    });
    const contact = this.config.get<string>('NOMINATIM_EMAIL');
    const userAgent = `TroTot/1.0 (room geocoding${contact ? `; ${contact}` : ''})`;
    const response = await fetch(
      `https://nominatim.openstreetmap.org/search?${query}`,
      {
        headers: { 'User-Agent': userAgent },
        signal: AbortSignal.timeout(8_000),
      },
    );
    if (!response.ok) {
      throw new Error(`Nominatim responded with HTTP ${response.status}.`);
    }

    const results = await response.json() as NominatimResult[];
    const first = results[0];
    if (!first) return null;
    const latitude = Number(first.lat);
    const longitude = Number(first.lon);
    if (
      !Number.isFinite(latitude) ||
      !Number.isFinite(longitude) ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180
    ) {
      throw new Error('Nominatim returned invalid coordinates.');
    }
    return { latitude, longitude };
  }
}
