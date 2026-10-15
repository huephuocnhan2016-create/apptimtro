import {
  Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, Put, Query,
  UploadedFile, UseGuards, UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { User, UserRole } from '@prisma/client';
import { Throttle } from '@nestjs/throttler';
import { memoryStorage } from 'multer';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AvailabilityDto } from './dto/availability.dto';
import { CreateRoomDto } from './dto/create-room.dto';
import { RoomSearchDto } from './dto/room-search.dto';
import { UpdateRoomDto } from './dto/update-room.dto';
import { RoomsService } from './rooms.service';
import { RoomImageUpload } from './storage.service';

@ApiTags('Rooms')
@Controller('rooms')
export class RoomsController {
  constructor(private readonly rooms: RoomsService) {}

  @Get('nearby')
  @ApiOperation({ summary: 'Find available rooms within a PostGIS radius' })
  nearby(@Query() query: RoomSearchDto) {
    return this.rooms.nearby(query);
  }

  @Get('search')
  search(@Query() query: RoomSearchDto) {
    return this.rooms.search(query);
  }

  @Get('filter')
  filter(@Query() query: RoomSearchDto) {
    return this.rooms.filter(query);
  }

  @Get('favorites')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  favorites(@CurrentUser() user: User) {
    return this.rooms.favorites(user);
  }

  @Post(':id/favorite')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  addFavorite(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.rooms.addFavorite(user, id);
  }

  @Delete(':id/favorite')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  removeFavorite(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.rooms.removeFavorite(user, id);
  }

  @Get('my')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.LANDLORD)
  myRooms(@CurrentUser() user: User) {
    return this.rooms.myRooms(user);
  }

  @Post()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.LANDLORD)
  create(@CurrentUser() user: User, @Body() dto: CreateRoomDto) {
    return this.rooms.create(user, dto);
  }

  @Get(':id')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  getOne(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.rooms.getOne(id, user);
  }

  @Post(':id/images')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @ApiBearerAuth()
  @ApiConsumes('multipart/form-data')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.LANDLORD)
  @UseInterceptors(FileInterceptor('image', {
    storage: memoryStorage(),
    limits: { fileSize: 10 * 1024 * 1024 },
  }))
  addImage(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @UploadedFile() file: RoomImageUpload,
  ) {
    return this.rooms.addImage(user, id, file);
  }

  @Delete(':id/images/:imageId')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.LANDLORD)
  removeImage(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('imageId', ParseUUIDPipe) imageId: string,
  ) {
    return this.rooms.removeImage(user, id, imageId);
  }

  @Patch(':id/availability')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.LANDLORD)
  updateAvailability(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AvailabilityDto,
  ) {
    return this.rooms.updateAvailability(user, id, dto);
  }

  @Put(':id')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.LANDLORD)
  update(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateRoomDto,
  ) {
    return this.rooms.update(user, id, dto);
  }

  @Delete(':id')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.LANDLORD)
  remove(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.rooms.remove(user, id);
  }
}
