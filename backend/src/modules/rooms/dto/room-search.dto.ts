import { Type } from 'class-transformer';
import { IsIn, IsNumber, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

export class RoomSearchDto {
  @IsOptional() @IsString() @MaxLength(120) query?: string;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(-90) @Max(90) latitude?: number;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(-180) @Max(180) longitude?: number;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0.1) @Max(1000) radius?: number;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) minPrice?: number;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) maxPrice?: number;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) minArea?: number;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) maxArea?: number;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) availableRooms?: number;
  @IsOptional() @IsString() @MaxLength(500) amenities?: string;
  @IsOptional() @IsIn(['distance', 'price_asc', 'price_desc', 'newest']) sort?: string;
}
