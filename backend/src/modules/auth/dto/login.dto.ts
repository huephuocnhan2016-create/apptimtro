import { ApiProperty } from '@nestjs/swagger';
import { IsString, Matches, MinLength } from 'class-validator';

export class LoginDto {
  @ApiProperty({ example: '+84901234567' })
  @IsString()
  @Matches(/^\+?\d{9,15}$/)
  phone!: string;

  @ApiProperty()
  @IsString()
  @MinLength(20)
  verificationToken!: string;
}
