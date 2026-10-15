import { Type } from 'class-transformer';
import { IsInt, Min } from 'class-validator';

export class AvailabilityDto {
  @Type(() => Number)
  @IsInt()
  @Min(0)
  availableRooms!: number;
}
