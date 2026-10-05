import { Global, Module } from '@nestjs/common';
import { AssignmentsModule } from '../assignments/assignments.module';
import { EscalationController } from './escalation.controller';
import { EscalationService } from './escalation.service';
import { EscalationSettingsService } from './escalation-settings.service';
import { KoordinatorAssignmentController } from './koordinator-assignment.controller';
import { KoordinatorAssignmentService } from './koordinator-assignment.service';
import { RomoRegistrationService } from './romo-registration.service';

@Global()
@Module({
  imports: [AssignmentsModule],
  controllers: [EscalationController, KoordinatorAssignmentController],
  providers: [EscalationSettingsService, EscalationService, KoordinatorAssignmentService, RomoRegistrationService],
  exports: [EscalationSettingsService, EscalationService],
})
export class EscalationModule {}
