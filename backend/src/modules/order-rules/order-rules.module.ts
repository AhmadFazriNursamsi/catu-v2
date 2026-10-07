import { Global, Module } from '@nestjs/common';
import { AcceptanceClaimService } from './acceptance-claim.service';
import { LintasParokiService } from './lintas-paroki.service';
import { OrderGuardsService } from './order-guards.service';

@Global()
@Module({
  providers: [AcceptanceClaimService, OrderGuardsService, LintasParokiService],
  exports: [AcceptanceClaimService, OrderGuardsService, LintasParokiService],
})
export class OrderRulesModule {}
