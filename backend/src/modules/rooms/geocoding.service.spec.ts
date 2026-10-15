import { ConfigService } from '@nestjs/config';
import { GeocodingService } from './geocoding.service';

describe('GeocodingService', () => {
  const config = { get: jest.fn() };
  let service: GeocodingService;
  let fetchSpy: jest.SpyInstance;

  beforeEach(() => {
    jest.clearAllMocks();
    config.get.mockReturnValue(undefined);
    service = new GeocodingService(config as unknown as ConfigService);
    fetchSpy = jest.spyOn(global, 'fetch');
  });

  afterEach(() => fetchSpy.mockRestore());

  it('looks up an address in Vietnam and returns coordinates', async () => {
    fetchSpy.mockResolvedValue(new Response(
      JSON.stringify([{ lat: '10.78', lon: '106.67' }]),
      { status: 200 },
    ));

    await expect(service.geocode('123 Nguyen Hue')).resolves.toEqual({
      latitude: 10.78,
      longitude: 106.67,
    });
    const [url, options] = fetchSpy.mock.calls[0];
    expect(String(url)).toContain('countrycodes=vn');
    expect(String(url)).toContain('123+Nguyen+Hue%2C+Vi%E1%BB%87t+Nam');
    expect(options.headers).toEqual({
      'User-Agent': 'TroTot/1.0 (room geocoding)',
    });
  });

  it('returns null when no matching address is found', async () => {
    fetchSpy.mockResolvedValue(new Response('[]', { status: 200 }));

    await expect(service.geocode('Unknown address')).resolves.toBeNull();
  });

  it('rejects unsuccessful responses rather than treating them as no match', async () => {
    fetchSpy.mockResolvedValue(new Response('service error', { status: 503 }));

    await expect(service.geocode('123 Nguyen Hue')).rejects.toThrow(
      'Nominatim responded with HTTP 503.',
    );
  });
});
