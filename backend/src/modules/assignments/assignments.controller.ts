import {
  Controller,
  Post,
  Body,
  Param,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { RespondOrderAssignmentDto } from '../../orders.dto';
import { AssignmentsService } from './assignments.service';

@ApiTags('Romo Assignments')
@Controller('assignments')
export class AssignmentsController {
  constructor(private readonly assignmentsService: AssignmentsService) {}

  @Post(':orderId/respond')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({
    summary: 'Romo mengubah status pelayanan: CONFIRMED | IN_PROGRESS | DONE | CLOSE | FAIL | ACCEPTED',
  })
  async respondAssignment(
    @Param('orderId') orderIdParam: string,
    @Body() dto: RespondOrderAssignmentDto,
  ) {
    return await this.assignmentsService.respondAssignment(orderIdParam, dto);
  }
}
