import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const clientError = this.bodyParserError(exception);
    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : clientError?.status ?? HttpStatus.INTERNAL_SERVER_ERROR;

    let message = clientError?.message ?? 'Terjadi kesalahan pada server internal';
    let errors: any = undefined;

    if (exception instanceof HttpException) {
      const res = exception.getResponse();
      if (typeof res === 'object' && res !== null) {
        message = (res as any).message || exception.message;
        errors = (res as any).errors;
      } else {
        message = exception.message;
      }
    } else if (clientError) {
      this.logger.warn(`Permintaan ditolak [${request.method}] ${request.url}: ${clientError.status} ${clientError.message}`);
    } else if (exception instanceof Error) {
      this.logger.error(
        `Unhandled Exception on [${request.method}] ${request.url}: ${exception.message}`,
        exception.stack,
      );
    } else {
      this.logger.error(`Unknown error on [${request.method}] ${request.url}: ${exception}`);
    }

    response.status(status).json({
      statusCode: status,
      timestamp: new Date().toISOString(),
      path: request.url,
      message,
      ...(errors ? { errors } : {}),
    });
  }

  /** Galat pembaca body Express (terlalu besar, JSON rusak) adalah salah klien, bukan galat server. */
  private bodyParserError(exception: unknown): { status: number; message: string } | null {
    const e = exception as { type?: string; status?: number } | null;
    if (e?.type === 'entity.too.large') return { status: HttpStatus.PAYLOAD_TOO_LARGE, message: 'Ukuran data yang dikirim terlalu besar.' };
    if (e?.type === 'entity.parse.failed') return { status: HttpStatus.BAD_REQUEST, message: 'Format data yang dikirim tidak valid.' };
    return null;
  }
}
