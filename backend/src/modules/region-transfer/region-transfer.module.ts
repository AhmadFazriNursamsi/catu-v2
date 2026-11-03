import { Module } from '@nestjs/common';
import { RegionTransferService } from './region-transfer.service';

@Module({ providers: [RegionTransferService], exports: [RegionTransferService] })
export class RegionTransferModule {}
