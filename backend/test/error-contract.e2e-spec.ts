import { Body, Controller, INestApplication, Post } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { json } from 'express';
import request from 'supertest';
import { AllExceptionsFilter } from '../src/all-exceptions.filter';

@Controller('probe')
class ProbeController {
  @Post()
  echo(@Body() body: { crash?: boolean }) {
    if (body.crash) throw new Error('rahasia internal');
    return { ok: true };
  }
}

/** Kontrak galat HTTP dengan pembaca body Express sungguhan: kesalahan klien tidak boleh menjadi 500. */
describe('Kontrak galat HTTP (Express + AllExceptionsFilter)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const mod = await Test.createTestingModule({ controllers: [ProbeController] }).compile();
    const nest = mod.createNestApplication<NestExpressApplication>({ bodyParser: false });
    nest.use(json({ limit: '1kb' }));
    nest.useGlobalFilters(new AllExceptionsFilter());
    app = await nest.init();
  });
  afterAll(() => app.close());

  it('body melebihi batas menjadi 413, bukan 500', async () => {
    const res = await request(app.getHttpServer()).post('/probe').send({ blob: 'x'.repeat(5000) });
    expect(res.status).toBe(413);
    expect(res.body.message).toMatch(/terlalu besar/);
  });

  it('JSON rusak menjadi 400', async () => {
    const res = await request(app.getHttpServer()).post('/probe').set('Content-Type', 'application/json').send('{"a":');
    expect(res.status).toBe(400);
  });

  it('galat tak dikenal tetap 500 dan tidak membocorkan pesan internal', async () => {
    const res = await request(app.getHttpServer()).post('/probe').send({ crash: true });
    expect(res.status).toBe(500);
    expect(JSON.stringify(res.body)).not.toContain('rahasia');
  });

  it('permintaan sah tetap berjalan', async () => {
    expect((await request(app.getHttpServer()).post('/probe').send({})).status).toBe(201);
  });
});
