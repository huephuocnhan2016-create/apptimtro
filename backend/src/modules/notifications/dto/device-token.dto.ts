import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class DeviceTokenDto {
  @IsString()
  @MaxLength(2048)
  token!: string;

  @IsOptional()
  @IsIn(['android', 'ios', 'web'])
  platform?: string;
}
