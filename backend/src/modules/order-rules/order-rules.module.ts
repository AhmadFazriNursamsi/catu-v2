import { Global, Injectable, Logger, Module, OnModuleInit } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { AcceptanceClaimService } from './acceptance-claim.service';
import { OrderGuardsService } from './order-guards.service';

/** Menyiapkan penghitung nomor pelayanan harian (lihat generateOrderNumber). */
@Injectable()
export class OrderNumberCounterSetup implements OnModuleInit {
  private readonly logger = new Logger('OrderNumberCounterSetup');

  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  async onModuleInit() {
    try {
      await this.dataSource.query(`CREATE TABLE IF NOT EXISTS order_number_counters (key VARCHAR(40) PRIMARY KEY, last_value INT NOT NULL DEFAULT 0)`);
    } catch (err) {
      this.logger.error(`Gagal menyiapkan penghitung nomor pelayanan: ${(err as Error).message}`);
    }
  }
}

@Global()
@Module({
  providers: [AcceptanceClaimService, OrderGuardsService, OrderNumberCounterSetup],
  exports: [AcceptanceClaimService, OrderGuardsService],
})
export class OrderRulesModule {}
