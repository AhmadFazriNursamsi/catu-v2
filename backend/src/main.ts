import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  app.enableCors();

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

  const port = process.env.PORT || 3000;
  await app.listen(port);
  console.log(`🚀 Aplikasi CATU v2 Backend berjalan di: http://localhost:${port}`);
  console.log(`📚 Dokumentasi Swagger OpenAPI berjalan di: http://localhost:${port}/api/docs`);
}
bootstrap();
