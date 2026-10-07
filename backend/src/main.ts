import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { autoMigrateEnabled, runMigrations } from './database/migrate';

import { json, urlencoded } from 'express';
import helmet from 'helmet';
import { AllExceptionsFilter } from './all-exceptions.filter';
import type { NestExpressApplication } from '@nestjs/platform-express';
import {
  assertSecureEnvironment,
  buildCorsOptions,
  bodyLimit,
  swaggerEnabled,
  trustProxySetting,
} from './common/config/bootstrap-config';

async function bootstrap() {
  assertSecureEnvironment();
  // Skema harus siap sebelum modul mana pun berjalan; gagal migrasi = aplikasi tidak start (bukan jalan dengan skema setengah jadi).
  if (autoMigrateEnabled()) await runMigrations();
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  app.set('trust proxy', trustProxySetting());
  app.use(helmet({ contentSecurityPolicy: false, crossOriginEmbedderPolicy: false }));
  app.use(json({ limit: bodyLimit() }));
  app.use(urlencoded({ limit: bodyLimit(), extended: true }));

  // Transparently support both /api/* and non-/api/* routes
  app.use((req: any, _res: any, next: any) => {
    if (req.url === '/api') {
      req.url = '/';
    } else if (req.url.startsWith('/api/') && !req.url.startsWith('/api/docs')) {
      req.url = req.url.replace(/^\/api/, '');
    }
    next();
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  app.useGlobalFilters(new AllExceptionsFilter());

  app.enableCors(buildCorsOptions());

  if (!swaggerEnabled()) {
    await app.listen(process.env.PORT || 3000, process.env.HOST || '0.0.0.0');
    return;
  }

  const config = new DocumentBuilder()
    .setTitle('CATU v2 API Documentation')
    .setDescription(
      'Dokumentasi API Sistem On-Demand Pelayanan Romo, Misa Kedukaan Multi-Item, Registration Approval Workflow, WhatsApp-Style Group Chat, & Live Unit Test Runner.',
    )
    .setVersion('2.0.0')
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        name: 'JWT',
        description: 'Masukkan JWT Token hasil login',
        in: 'header',
      },
      'JWT-auth',
    )
    .addTag('Auth & Registration', 'Endpoint Pendaftaran & Persetujuan Akun')
    .addTag('Orders & Pelayanan', 'Endpoint Pemesanan Pelayanan & Misa Kedukaan')
    .addTag('Romo Assignments', 'Endpoint Penerimaan / Penolakan Pelayanan oleh Romo')
    .addTag('Group Chat', 'Endpoint Fitur WhatsApp-Style Group Chat')
    .addTag('Testing & Quality Assurance', 'Endpoint Eksekusi Live Unit Test Runner (Jest)')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);
  SwaggerModule.setup('docs', app, document);

  const port = process.env.PORT || 3000;
  const host = process.env.HOST || '0.0.0.0';
  await app.listen(port, host);
  console.log(`🚀 Aplikasi CATU v2 Backend berjalan di: http://${host}:${port}`);
  console.log(`📚 Dokumentasi Swagger OpenAPI berjalan di: http://${host}:${port}/api/docs`);
}
bootstrap().catch((err) => {
  console.error('Aplikasi gagal start:', err instanceof Error ? err.message : err);
  process.exit(1);
});
