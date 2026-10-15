import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { User } from '@prisma/client';
import { Request } from 'express';

export type AuthenticatedRequest = Request & { user: User };

export const CurrentUser = createParamDecorator(
  (_data: unknown, context: ExecutionContext): User =>
    context.switchToHttp().getRequest<AuthenticatedRequest>().user,
);
