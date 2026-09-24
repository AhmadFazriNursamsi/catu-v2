import { Module } from '@nestjs/common';
import { MasterDataController } from './master-data.controller';
import { MasterDataService } from './master-data.service';
import { GeoMasterDataController } from './geo-master-data.controller';
import { GeoMasterDataService } from './geo-master-data.service';

@Module({
  controllers: [MasterDataController, GeoMasterDataController],
  providers: [MasterDataService, GeoMasterDataService],
  exports: [MasterDataService, GeoMasterDataService],
})
export class MasterDataModule {}
