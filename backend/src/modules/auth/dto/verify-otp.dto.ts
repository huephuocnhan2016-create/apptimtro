import { ApiProperty } from '@nestjs/swagger';
import { IsString, Matches } from 'class-validator';

export class VerifyOtpDto {
  @ApiProperty({ example: '+84901234567' })
  @IsString()
  @Matches(/^\+?\d{9,15}$/)
  phone!: string;

  @ApiProperty({ example: '123456' })
  @IsString()
  @Matches(/^\d{6}$/)
  otp!: string;
}
