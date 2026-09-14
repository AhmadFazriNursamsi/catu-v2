import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { DataSource } from 'typeorm';

@ApiTags('System & Health')
@Controller('health')
export class HealthController {
  constructor(private readonly dataSource: DataSource) {}

  @Get()
  @ApiOperation({ summary: 'Periksa status kesehatan sistem, database PostgreSQL, dan memori' })
  @ApiResponse({ status: 200, description: 'Sistem dan Database sehat' })
  @ApiResponse({ status: 503, description: 'Sistem atau Database sedang mengalami gangguan' })
  async checkHealth() {
    const startTime = Date.now();
    let dbStatus = 'down';
    let dbLatencyMs = -1;

    try {
      const dbStart = Date.now();
      await this.dataSource.query('SELECT 1');
      dbLatencyMs = Date.now() - dbStart;
      dbStatus = 'up';
    } catch (err: any) {
      dbStatus = `down: ${err?.message || 'unknown error'}`;
    }

    const memoryUsage = process.memoryUsage();
    const isHealthy = dbStatus === 'up';

    const healthData = {
      status: isHealthy ? 'ok' : 'error',
      timestamp: new Date().toISOString(),
      uptimeSeconds: Math.floor(process.uptime()),
      database: {
        status: dbStatus,
        latencyMs: dbLatencyMs,
      },
      memory: {
        rssMb: Math.round((memoryUsage.rss / 1024 / 1024) * 100) / 100,
        heapUsedMb: Math.round((memoryUsage.heapUsed / 1024 / 1024) * 100) / 100,
        heapTotalMb: Math.round((memoryUsage.heapTotal / 1024 / 1024) * 100) / 100,
      },
      checkDurationMs: Date.now() - startTime,
    };

    if (!isHealthy) {
      throw new ServiceUnavailableException(healthData);
    }

    return healthData;
  }
}
