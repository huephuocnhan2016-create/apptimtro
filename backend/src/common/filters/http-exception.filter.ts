import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const context = host.switchToHttp();
    const request = context.getRequest<Request>();
    const response = context.getResponse<Response>();
    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;
    const body = exception instanceof HttpException
      ? exception.getResponse()
      : null;
    const rawMessage = typeof body === 'object' && body !== null && 'message' in body
      ? (body as { message: unknown }).message
      : body;
    const message = Array.isArray(rawMessage)
      ? rawMessage.join(', ')
      : typeof rawMessage === 'string'
        ? rawMessage
        : 'Internal server error';
    const code = status === 400 ? 'VALIDATION_ERROR'
      : status === 401 ? 'UNAUTHORIZED'
      : status === 403 ? 'FORBIDDEN'
      : status === 404 ? 'NOT_FOUND'
      : status === 409 ? 'CONFLICT'
      : status === 422 ? 'UNPROCESSABLE_ENTITY'
      : status === 429 ? 'RATE_LIMITED'
      : status >= 500 ? 'INTERNAL_ERROR'
      : 'REQUEST_ERROR';

    if (!(exception instanceof HttpException)) {
      this.logger.error(
        exception instanceof Error ? exception.stack : String(exception),
      );
    }
    response.status(status).json({
      success: false,
      message,
      code,
      data: null,
      ...(process.env.NODE_ENV !== 'production'
        ? { path: request.url, timestamp: new Date().toISOString() }
        : {}),
    });
  }
}
