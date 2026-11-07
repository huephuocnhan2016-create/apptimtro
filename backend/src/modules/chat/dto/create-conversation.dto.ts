import { IsUUID } from 'class-validator';

export class CreateConversationDto {
  @IsUUID()
  roomId!: string;
}
