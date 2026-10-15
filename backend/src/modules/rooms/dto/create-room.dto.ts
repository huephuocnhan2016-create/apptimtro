import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateRoomDto {
  @IsString()
  @MaxLength(160)
  title!: string;

  @IsString()
  @MaxLength(10000)
  description!: string;

  @IsString()
  @MaxLength(500)
  address!: string;

  @IsOptional()
  @Transform(({ value }) => value == null ? value : Number(value))
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number | null;

  @IsOptional()
  @Transform(({ value }) => value == null ? value : Number(value))
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number | null;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(10_000_000_000)
  price!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0.1)
  @Max(10000)
  area!: number;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  totalRooms!: number;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  availableRooms!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(10_000_000_000)
  electricityPrice!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(10_000_000_000)
  waterPrice!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(10_000_000_000)
  internetPrice!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(10_000_000_000)
  deposit!: number;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @IsString({ each: true })
  amenities?: string[];
}
