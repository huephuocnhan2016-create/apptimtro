import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import {
  IsEmail,
  IsIn,
  IsString,
  Matches,
  MaxLength,
  MinLength,
  ValidateIf,
} from 'class-validator';

export class RegisterDto {
  @ApiProperty({ example: '+84901234567' })
  @IsString()
  @Matches(/^\+?\d{9,15}$/)
  phone!: string;

  @ApiProperty()
  @IsString()
  @MinLength(20)
  verificationToken!: string;

  @ApiProperty({ enum: [UserRole.STUDENT, UserRole.LANDLORD] })
  @IsIn([UserRole.STUDENT, UserRole.LANDLORD])
  role!: UserRole;

  @ApiProperty({ example: 'Nguyễn Minh Anh' })
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  fullName!: string;

  @ApiPropertyOptional({ example: 'minhanh@example.com' })
  @ValidateIf((dto: RegisterDto) => dto.role === UserRole.LANDLORD)
  @IsEmail()
  @MaxLength(320)
  email?: string;
}
