import { IsUUID } from 'class-validator';

export class CreateCallDto {
  @IsUUID()
  roomId!: string;
}
