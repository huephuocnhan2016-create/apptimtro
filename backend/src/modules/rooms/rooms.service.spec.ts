import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { RoomStatus, User, UserRole } from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { CreateRoomDto } from './dto/create-room.dto';
import { GeocodingService } from './geocoding.service';
import { RoomsService } from './rooms.service';
import { StorageService } from './storage.service';

const landlord = {
  id: '3150027c-71b7-4c07-8e54-3d1b61e8cb98',
  role: UserRole.LANDLORD,
} as User;

const room = {
  id: 'ab8f513e-b394-42e3-98bc-b29e0f9ffbbd',
  landlordId: landlord.id,
  title: 'Room',
  description: '',
  address: 'District 1',
  latitude: 10.77,
  longitude: 106.66,
  price: 5000000,
  area: 20,
  totalRooms: 3,
  availableRooms: 2,
  electricityPrice: 3000,
  waterPrice: 10000,
  internetPrice: 100000,
  deposit: 5000000,
  status: RoomStatus.AVAILABLE,
  amenities: [],
  images: [],
  landlord: { id: landlord.id, fullName: 'Landlord', phone: '0900000000' },
};

describe('RoomsService', () => {
  const prisma = {
    room: {
      create: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
      findMany: jest.fn(),
      findFirst: jest.fn(),
      aggregate: jest.fn(),
    },
    roomImage: { create: jest.fn(), findFirst: jest.fn(), delete: jest.fn() },
    favorite: {
      upsert: jest.fn(),
      deleteMany: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn(),
    },
    $queryRaw: jest.fn(),
  };
  const storage = { store: jest.fn(), remove: jest.fn() };
  const geocoding = { geocode: jest.fn() };
  const service = new RoomsService(
    prisma as unknown as PrismaService,
    storage as unknown as StorageService,
    geocoding as unknown as GeocodingService,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    geocoding.geocode.mockResolvedValue(null);
  });

  it('creates a room owned by the authenticated landlord', async () => {
    prisma.room.create.mockResolvedValue(room);
    const result = await service.create(landlord, {
      title: 'Room',
      description: '',
      address: 'District 1',
      latitude: 10.77,
      longitude: 106.66,
      price: 5000000,
      area: 20,
      totalRooms: 3,
      availableRooms: 2,
      electricityPrice: 3000,
      waterPrice: 10000,
      internetPrice: 100000,
      deposit: 5000000,
    } satisfies CreateRoomDto);

    expect(prisma.room.create.mock.calls[0][0].data.landlordId).toBe(landlord.id);
    expect(prisma.room.create.mock.calls[0][0].data.status).toBe(RoomStatus.AVAILABLE);
    expect(result.price).toBe(5000000);
  });

  it('creates a room with an address when coordinates are unavailable', async () => {
    prisma.room.create.mockResolvedValue({
      ...room,
      latitude: null,
      longitude: null,
    });

    const result = await service.create(landlord, {
      title: 'Room',
      description: '',
      address: 'District 1',
      price: 5000000,
      area: 20,
      totalRooms: 3,
      availableRooms: 2,
      electricityPrice: 3000,
      waterPrice: 10000,
      internetPrice: 100000,
      deposit: 5000000,
    } satisfies CreateRoomDto);

    expect(prisma.room.create.mock.calls[0][0].data).toMatchObject({
      latitude: null,
      longitude: null,
    });
    expect(result.latitude).toBeNull();
    expect(result.longitude).toBeNull();
    expect(geocoding.geocode).toHaveBeenCalledWith('District 1');
  });

  it('keeps an address-only room when geocoding is unavailable', async () => {
    geocoding.geocode.mockRejectedValue(new Error('Nominatim unavailable'));
    prisma.room.create.mockResolvedValue({
      ...room,
      latitude: null,
      longitude: null,
    });

    const result = await service.create(landlord, {
      title: 'Room',
      description: '',
      address: 'District 1',
      price: 5000000,
      area: 20,
      totalRooms: 3,
      availableRooms: 2,
      electricityPrice: 3000,
      waterPrice: 10000,
      internetPrice: 100000,
      deposit: 5000000,
    } satisfies CreateRoomDto);

    expect(prisma.room.create.mock.calls[0][0].data).toMatchObject({
      latitude: null,
      longitude: null,
    });
    expect(result.latitude).toBeNull();
  });

  it('uses server-geocoded coordinates when a room is created from an address', async () => {
    geocoding.geocode.mockResolvedValue({ latitude: 10.78, longitude: 106.67 });
    prisma.room.create.mockResolvedValue({
      ...room,
      latitude: 10.78,
      longitude: 106.67,
    });

    await service.create(landlord, {
      title: 'Room',
      description: '',
      address: '123 Nguyen Hue, Ho Chi Minh City',
      price: 5000000,
      area: 20,
      totalRooms: 3,
      availableRooms: 2,
      electricityPrice: 3000,
      waterPrice: 10000,
      internetPrice: 100000,
      deposit: 5000000,
    } satisfies CreateRoomDto);

    expect(prisma.room.create.mock.calls[0][0].data).toMatchObject({
      latitude: 10.78,
      longitude: 106.67,
    });
  });

  it('rejects a room with only one coordinate', async () => {
    await expect(service.create(landlord, {
      latitude: 10.77,
    } as CreateRoomDto)).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.room.create).not.toHaveBeenCalled();
  });

  it('updates rooms owned by the current landlord', async () => {
    prisma.room.findUnique.mockResolvedValue(room);
    prisma.room.update.mockResolvedValue({ ...room, title: 'Updated' });

    const result = await service.update(landlord, room.id, { title: 'Updated' });

    expect(prisma.room.update.mock.calls[0][0].where.id).toBe(room.id);
    expect(result.title).toBe('Updated');
  });

  it('re-geocodes an updated room address', async () => {
    prisma.room.findUnique.mockResolvedValue(room);
    geocoding.geocode.mockResolvedValue({ latitude: 10.78, longitude: 106.67 });
    prisma.room.update.mockResolvedValue({
      ...room,
      address: '123 Nguyen Hue, Ho Chi Minh City',
      latitude: 10.78,
      longitude: 106.67,
    });

    await service.update(landlord, room.id, {
      address: '123 Nguyen Hue, Ho Chi Minh City',
      latitude: null,
      longitude: null,
    });

    expect(geocoding.geocode).toHaveBeenCalledWith('123 Nguyen Hue, Ho Chi Minh City');
    expect(prisma.room.update.mock.calls[0][0].data).toMatchObject({
      latitude: 10.78,
      longitude: 106.67,
    });
  });

  it('rejects edits and deletes by a landlord who does not own the room', async () => {
    prisma.room.findUnique.mockResolvedValue({
      ...room,
      landlordId: 'd70a54ef-86e1-4b9d-b970-b6c5eef14654',
    });
    await expect(service.update(landlord, room.id, { title: 'Nope' }))
      .rejects.toBeInstanceOf(ForbiddenException);
    await expect(service.remove(landlord, room.id))
      .rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.room.delete).not.toHaveBeenCalled();
  });

  it('deletes a room owned by the current landlord', async () => {
    prisma.room.findUnique.mockResolvedValue(room);
    prisma.room.delete.mockResolvedValue(room);
    await expect(service.remove(landlord, room.id)).resolves.toEqual({ deleted: true });
    expect(prisma.room.delete).toHaveBeenCalledWith({ where: { id: room.id } });
  });

  it('uses PostGIS distance functions for nearby room lookup', async () => {
    prisma.$queryRaw.mockResolvedValue([{ id: room.id, distance: 1.25 }]);
    prisma.room.findMany.mockResolvedValue([room]);

    const results = await service.nearby({ latitude: 10.77, longitude: 106.66, radius: 5 });

    expect(prisma.$queryRaw.mock.calls[0][0].sql).toContain('ST_DWithin');
    expect(results[0].distance).toBe(1.25);
  });

  it('applies price, area, availability, and amenity filters in the database query', async () => {
    prisma.$queryRaw.mockResolvedValue([]);

    await service.filter({
      minPrice: 1000000,
      maxPrice: 6000000,
      minArea: 15,
      maxArea: 30,
      availableRooms: 1,
      amenities: 'wifi,parking',
    });

    const sql = prisma.$queryRaw.mock.calls[0][0].sql;
    expect(sql).toContain('"price" >=');
    expect(sql).toContain('"area" <=');
    expect(sql).toContain('"available_rooms" >=');
    expect(sql).toContain('"amenities" @>');
  });

  it('rejects non-landlords from room management operations', async () => {
    await expect(
      service.create({ ...landlord, role: UserRole.STUDENT }, {} as CreateRoomDto),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('adds a favorite for a visible room using the authenticated user id', async () => {
    prisma.room.findFirst.mockResolvedValue(room);
    prisma.favorite.upsert.mockResolvedValue({});
    const student = { ...landlord, role: UserRole.STUDENT } as User;

    await expect(service.addFavorite(student, room.id)).resolves.toEqual({
      favorited: true,
    });
    expect(prisma.favorite.upsert.mock.calls[0][0].where).toEqual({
      userId_roomId: { userId: student.id, roomId: room.id },
    });
  });
});
