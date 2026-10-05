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
import { AssignmentWorkflowService } from './assignment-workflow.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AccessService, AuthUser } from '../../common/access/access.service';
import { ADMIN_ROLES, ROMO_ROLES } from '../../common/access/role-groups';
import { EscalationService } from '../escalation/escalation.service';

@ApiTags('Romo Assignments')
@Controller('assignments')
export class AssignmentsController {
  constructor(
    private readonly workflow: AssignmentWorkflowService,
    private readonly access: AccessService,
    private readonly escalation: EscalationService,
  ) {}

  @Post(':orderId/respond')
  @Roles(...ROMO_ROLES, ...ADMIN_ROLES)
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({
    summary: 'Romo mengubah status pelayanan: CONFIRMED | IN_PROGRESS | DONE | CLOSE | FAIL | ACCEPTED',
  })
  async respondAssignment(
    @CurrentUser() user: AuthUser,
    @Param('orderId') orderIdParam: string,
    @Body() dto: RespondOrderAssignmentDto,
  ) {
    // Romo yang memproses selalu identitas dari token (admin boleh bertindak atas nama romo lain).
    const romoId = this.access.isAdmin(user) ? dto.romoId : user.sub;
    if (!this.access.isAdmin(user)) await this.escalation.assertCanAccept(user, parseInt(orderIdParam, 10) || 0, dto.status);
    return await this.workflow.respond(parseInt(orderIdParam, 10) || 0, dto, { romoId, isAdmin: this.access.isAdmin(user) });
  }
}
