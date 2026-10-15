import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsString, Matches } from 'class-validator';
import { UserRole } from '@prisma/client';

export class SendOtpDto {
  @ApiProperty({ example: '+84901234567' })
  @IsString()
  @Matches(/^\+?\d{9,15}$/)
  phone!: string;

  @ApiProperty({ enum: [UserRole.STUDENT, UserRole.LANDLORD] })
  @IsIn([UserRole.STUDENT, UserRole.LANDLORD])
  role!: UserRole;
}
