import { Module } from '@nestjs/common';
import { AssignmentsController } from './assignments.controller';
import { AssignmentsService } from './assignments.service';
import { AssignmentWorkflowService } from './assignment-workflow.service';
import { FcmModule } from '../fcm/fcm.module';

@Module({
  imports: [FcmModule],
  controllers: [AssignmentsController],
  providers: [AssignmentsService, AssignmentWorkflowService],
  exports: [AssignmentsService],
})
export class AssignmentsModule {}
