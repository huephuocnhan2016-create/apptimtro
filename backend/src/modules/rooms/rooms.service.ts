import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { PaymentStatus, Prisma, RoomStatus, User, UserRole } from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { AvailabilityDto } from './dto/availability.dto';
import { CreateRoomDto } from './dto/create-room.dto';
import { GeocodingService } from './geocoding.service';
import { RoomSearchDto } from './dto/room-search.dto';
import { UpdateRoomDto } from './dto/update-room.dto';
import { RoomImageUpload, STORAGE_SERVICE, StorageService } from './storage.service';

const roomIncludes = {
  images: { orderBy: { sortOrder: 'asc' as const } },
  landlord: { select: { id: true, fullName: true, avatarUrl: true } },
};

@Injectable()
export class RoomsService {
  private readonly logger = new Logger(RoomsService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(STORAGE_SERVICE) private readonly storage: StorageService,
    private readonly geocoding: GeocodingService,
  ) {}

  async create(user: User, dto: CreateRoomDto) {
    this.assertLandlord(user);
    this.validateCounts(dto.totalRooms, dto.availableRooms);
    this.validateCoordinatePair(dto.latitude, dto.longitude);
    const coordinates = dto.latitude == null
      ? await this.geocodeAddress(dto.address)
      : { latitude: dto.latitude, longitude: dto.longitude };
    return this.serialize(await this.prisma.room.create({
      data: {
        ...dto,
        ...coordinates,
        landlordId: user.id,
        status: this.statusFor(dto.availableRooms),
      },
      include: roomIncludes,
    }));
  }

  async myRooms(user: User) {
    this.assertLandlord(user);
    const rooms = await this.prisma.room.findMany({
      where: { landlordId: user.id },
      include: roomIncludes,
      orderBy: { createdAt: 'desc' },
    });
    return rooms.map((room) => this.serialize(room));
  }

  async getOne(id: string, user?: User) {
    const room = await this.prisma.room.findUnique({
      where: { id },
      include: {
        ...roomIncludes,
        landlord: { select: { id: true, fullName: true, phone: true, avatarUrl: true } },
      },
    });
    if (!room) throw new NotFoundException('Room not found.');
    if ((room.status === RoomStatus.HIDDEN || room.status === RoomStatus.PENDING) &&
        room.landlordId !== user?.id) {
      throw new NotFoundException('Room not found.');
    }
    const isFavorite = user
      ? Boolean(await this.prisma.favorite.findUnique({
          where: { userId_roomId: { userId: user.id, roomId: id } },
          select: { id: true },
        }))
      : false;
    // One deposit per student per room, so the app can close the door before
    // it sends the shopper to the gate.
    const hasDeposit = user
      ? Boolean(await this.prisma.payment.findFirst({
          where: { studentId: user.id, roomId: id, status: PaymentStatus.PAID },
          select: { id: true },
        }))
      : false;
    const rating = await this.prisma.roomReview.aggregate({
      where: { roomId: id },
      _avg: { rating: true },
      _count: true,
    });
    return {
      ...this.serialize(room),
      isFavorite,
      hasDeposit,
      rating: { average: rating._avg.rating ?? null, count: rating._count },
      // The write endpoint repeats this check; the flag only hides the button.
      canReview: user?.role === UserRole.STUDENT && hasDeposit,
    };
  }

  async update(user: User, id: string, dto: UpdateRoomDto) {
    this.assertLandlord(user);
    const current = await this.ownedRoom(user, id);
    const totalRooms = dto.totalRooms ?? current.totalRooms;
    const availableRooms = dto.availableRooms ?? current.availableRooms;
    this.validateCounts(totalRooms, availableRooms);
    this.validateCoordinatePair(
      dto.latitude === undefined ? current.latitude : dto.latitude,
      dto.longitude === undefined ? current.longitude : dto.longitude,
    );
    const { availableRooms: _availability, ...updates } = dto;
    let coordinates: { latitude: number | null; longitude: number | null } | undefined;
    if (dto.latitude != null && dto.longitude != null) {
      coordinates = { latitude: dto.latitude, longitude: dto.longitude };
    } else if (
      dto.address !== undefined ||
      current.latitude == null ||
      current.longitude == null
    ) {
      coordinates = await this.geocodeAddress(dto.address ?? current.address);
    }
    return this.serialize(await this.prisma.room.update({
      where: { id },
      data: {
        ...updates,
        ...coordinates,
        totalRooms,
        availableRooms,
        status: this.statusFor(availableRooms, current.status),
      },
      include: roomIncludes,
    }));
  }

  async remove(user: User, id: string) {
    this.assertLandlord(user);
    await this.ownedRoom(user, id);
    await this.prisma.room.delete({ where: { id } });
    return { deleted: true };
  }

  async updateAvailability(user: User, id: string, dto: AvailabilityDto) {
    this.assertLandlord(user);
    const current = await this.ownedRoom(user, id);
    this.validateCounts(current.totalRooms, dto.availableRooms);
    return this.serialize(await this.prisma.room.update({
      where: { id },
      data: {
        availableRooms: dto.availableRooms,
        status: this.statusFor(dto.availableRooms, current.status),
      },
      include: roomIncludes,
    }));
  }

  async addImage(user: User, id: string, file: RoomImageUpload) {
    this.assertLandlord(user);
    const room = await this.ownedRoom(user, id);
    if (!file || !this.isSupportedImage(file)) {
      throw new BadRequestException('Upload a JPEG, PNG, WebP, or GIF image.');
    }
    const imageUrl = await this.storage.store(file);
    try {
      const lastImage = await this.prisma.roomImage.aggregate({
        where: { roomId: room.id },
        _max: { sortOrder: true },
      });
      const image = await this.prisma.roomImage.create({
        data: {
          roomId: room.id,
          imageUrl,
          sortOrder: (lastImage._max.sortOrder ?? -1) + 1,
        },
      });
      return image;
    } catch (error) {
      await this.storage.remove(imageUrl);
      throw error;
    }
  }

  async removeImage(user: User, id: string, imageId: string) {
    this.assertLandlord(user);
    await this.ownedRoom(user, id);
    const image = await this.prisma.roomImage.findFirst({
      where: { id: imageId, roomId: id },
    });
    if (!image) throw new NotFoundException('Room image not found.');
    await this.prisma.roomImage.delete({ where: { id: image.id } });
    await this.storage.remove(image.imageUrl);
    return { deleted: true };
  }

  async nearby(dto: RoomSearchDto) {
    if (dto.latitude === undefined || dto.longitude === undefined) {
      throw new BadRequestException('latitude and longitude are required.');
    }
    return this.findRooms(dto, dto.radius ?? 5);
  }

  async search(dto: RoomSearchDto) {
    if (dto.radius !== undefined &&
        (dto.latitude === undefined || dto.longitude === undefined)) {
      throw new BadRequestException('latitude and longitude are required when radius is set.');
    }
    return this.findRooms(dto);
  }

  async filter(dto: RoomSearchDto) {
    if (dto.radius !== undefined &&
        (dto.latitude === undefined || dto.longitude === undefined)) {
      throw new BadRequestException('latitude and longitude are required when radius is set.');
    }
    return this.findRooms(dto);
  }

  async addFavorite(user: User, roomId: string) {
    const room = await this.prisma.room.findFirst({
      where: { id: roomId, status: { in: [RoomStatus.AVAILABLE, RoomStatus.FULL, RoomStatus.DEPOSITED] } },
    });
    if (!room) throw new NotFoundException('Room not found.');
    await this.prisma.favorite.upsert({
      where: { userId_roomId: { userId: user.id, roomId } },
      create: { userId: user.id, roomId },
      update: {},
    });
    return { favorited: true };
  }

  async removeFavorite(user: User, roomId: string) {
    await this.prisma.favorite.deleteMany({ where: { userId: user.id, roomId } });
    return { favorited: false };
  }

  async favorites(user: User) {
    const favorites = await this.prisma.favorite.findMany({
      where: { userId: user.id },
      include: { room: { include: roomIncludes } },
      orderBy: { createdAt: 'desc' },
    });
    const visible: RoomStatus[] = [
      RoomStatus.AVAILABLE,
      RoomStatus.FULL,
      RoomStatus.DEPOSITED,
    ];
    return favorites
      .filter(({ room }) => visible.includes(room.status))
      .map(({ room }) => this.serialize(room));
  }

  /// `%` và `_` là ký tự đại diện của LIKE, phải giữ lại nghĩa thật để người
  /// dùng tìm "100%" hay "2_4" không khớp toàn bộ phòng.
  private likePattern(query: string) {
    return `%${query.replace(/[\\%_]/g, (char) => `\\${char}`)}%`;
  }

  private async findRooms(dto: RoomSearchDto, nearbyRadius?: number) {
    if (dto.minPrice !== undefined && dto.maxPrice !== undefined &&
        dto.minPrice > dto.maxPrice) {
      throw new BadRequestException('minPrice cannot be greater than maxPrice.');
    }
    if (dto.minArea !== undefined && dto.maxArea !== undefined &&
        dto.minArea > dto.maxArea) {
      throw new BadRequestException('minArea cannot be greater than maxArea.');
    }
    const amenities = dto.amenities
      ?.split(',')
      .map((item) => item.trim())
      .filter(Boolean);
    const keyword = dto.query ? this.likePattern(dto.query) : undefined;
    const filters = [
      Prisma.sql`"status" IN ('AVAILABLE', 'DEPOSITED')`,
      keyword
        ? Prisma.sql`("title" ILIKE ${keyword} OR "description" ILIKE ${keyword} OR "address" ILIKE ${keyword})`
        : Prisma.empty,
      dto.minPrice !== undefined ? Prisma.sql`"price" >= ${dto.minPrice}` : Prisma.empty,
      dto.maxPrice !== undefined ? Prisma.sql`"price" <= ${dto.maxPrice}` : Prisma.empty,
      dto.minArea !== undefined ? Prisma.sql`"area" >= ${dto.minArea}` : Prisma.empty,
      dto.maxArea !== undefined ? Prisma.sql`"area" <= ${dto.maxArea}` : Prisma.empty,
      dto.availableRooms !== undefined ? Prisma.sql`"available_rooms" >= ${dto.availableRooms}` : Prisma.empty,
      amenities?.length
        ? Prisma.join(
            amenities.map((amenity) => Prisma.sql`EXISTS (SELECT 1 FROM unnest("amenities") AS matched(name) WHERE lower(matched.name) = lower(${amenity}))`),
            ' AND ',
          )
        : Prisma.empty,
      nearbyRadius !== undefined
        ? Prisma.sql`ST_DWithin("location", ST_SetSRID(ST_MakePoint(${dto.longitude!}, ${dto.latitude!}), 4326)::geography, ${nearbyRadius * 1000})`
        : dto.radius !== undefined
          ? Prisma.sql`ST_DWithin("location", ST_SetSRID(ST_MakePoint(${dto.longitude!}, ${dto.latitude!}), 4326)::geography, ${dto.radius * 1000})`
          : Prisma.empty,
    ].filter((fragment) => fragment !== Prisma.empty);
    const where = Prisma.join(filters, ' AND ');
    const sort = dto.sort ?? (nearbyRadius !== undefined ? 'distance' : 'newest');
    let ordering: Prisma.Sql;
    switch (sort) {
      case 'distance':
        if (dto.latitude === undefined || dto.longitude === undefined) {
          throw new BadRequestException('latitude and longitude are required to sort by distance.');
        }
        ordering = Prisma.sql`ST_Distance("location", ST_SetSRID(ST_MakePoint(${dto.longitude}, ${dto.latitude}), 4326)::geography) ASC`;
        break;
      case 'price_asc': ordering = Prisma.sql`"price" ASC`; break;
      case 'price_desc': ordering = Prisma.sql`"price" DESC`; break;
      case 'newest': ordering = Prisma.sql`"created_at" DESC`; break;
      default: throw new BadRequestException('sort must be distance, price_asc, price_desc, or newest.');
    }
    const rows = await this.prisma.$queryRaw<Array<{ id: string; distance: number | null }>>(
      Prisma.sql`SELECT "id", CASE WHEN ${dto.latitude !== undefined && dto.longitude !== undefined}
        THEN ST_Distance("location", ST_SetSRID(ST_MakePoint(${dto.longitude ?? 0}, ${dto.latitude ?? 0}), 4326)::geography) / 1000.0
        ELSE NULL END AS "distance"
        FROM "rooms" WHERE ${where} ORDER BY ${ordering} LIMIT 100`,
    );
    if (!rows.length) return [];
    const rooms = await this.prisma.room.findMany({
      where: { id: { in: rows.map(({ id }) => id) } },
      include: roomIncludes,
    });
    const byId = new Map(rooms.map((room) => [room.id, room]));
    return rows.flatMap(({ id, distance }) => {
      const room = byId.get(id);
      if (!room) return [];
      return [this.serialize(room, distance)];
    });
  }

  private async ownedRoom(user: User, id: string) {
    const room = await this.prisma.room.findUnique({ where: { id } });
    if (!room) throw new NotFoundException('Room not found.');
    if (room.landlordId !== user.id) throw new ForbiddenException('You do not own this room.');
    return room;
  }

  private assertLandlord(user: User) {
    if (user.role !== UserRole.LANDLORD) {
      throw new ForbiddenException('This action requires a landlord account.');
    }
  }

  private validateCounts(total: number, available: number) {
    if (total < 1 || available < 0 || available > total) {
      throw new BadRequestException('availableRooms must be between 0 and totalRooms.');
    }
  }

  private validateCoordinatePair(
    latitude: number | null | undefined,
    longitude: number | null | undefined,
  ) {
    if ((latitude == null) !== (longitude == null)) {
      throw new BadRequestException('latitude and longitude must both be provided or both be null.');
    }
  }

  private async geocodeAddress(address: string) {
    try {
      const coordinates = await this.geocoding.geocode(address);
      if (!coordinates) {
        this.logger.warn('No map coordinates found for a room address.');
        return { latitude: null, longitude: null };
      }
      return coordinates;
    } catch (error) {
      this.logger.warn(
        'Address geocoding failed; saving the room without map coordinates.',
        error instanceof Error ? error.name : 'Unknown error',
      );
      return { latitude: null, longitude: null };
    }
  }

  private statusFor(available: number, current?: RoomStatus) {
    if (available > 0) return RoomStatus.AVAILABLE;
    // Deposits, not the landlord, emptied the listing — keep that reason visible.
    return current === RoomStatus.DEPOSITED
      ? RoomStatus.DEPOSITED
      : RoomStatus.FULL;
  }

  private isSupportedImage(file: RoomImageUpload) {
    const buffer = file.buffer;
    if (!buffer?.length) return false;
    switch (file.mimetype) {
      case 'image/jpeg':
        return buffer.length >= 3 && buffer[0] === 0xff &&
          buffer[1] === 0xd8 && buffer[2] === 0xff;
      case 'image/png':
        return buffer.length >= 8 &&
          buffer.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
      case 'image/webp':
        return buffer.length >= 12 && buffer.toString('ascii', 0, 4) === 'RIFF' &&
          buffer.toString('ascii', 8, 12) === 'WEBP';
      case 'image/gif':
        return buffer.length >= 6 &&
          ['GIF87a', 'GIF89a'].includes(buffer.toString('ascii', 0, 6));
      default:
        return false;
    }
  }

  private serialize(room: any, distance?: number | null) {
    const { price, electricityPrice, waterPrice, internetPrice, deposit, ...rest } = room;
    return {
      ...rest,
      price: Number(price),
      electricityPrice: Number(electricityPrice),
      waterPrice: Number(waterPrice),
      internetPrice: Number(internetPrice),
      deposit: Number(deposit),
      image: room.images?.[0]?.imageUrl ?? null,
      ...(distance !== undefined ? { distance } : {}),
    };
  }
}
