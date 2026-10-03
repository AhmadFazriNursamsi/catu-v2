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
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AccessService, AuthUser } from '../../common/access/access.service';
import { ADMIN_ROLES, ROMO_ROLES } from '../../common/access/role-groups';

@ApiTags('Romo Assignments')
@Controller('assignments')
export class AssignmentsController {
  constructor(
    private readonly assignmentsService: AssignmentsService,
    private readonly access: AccessService,
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
    return await this.assignmentsService.respondAssignment(orderIdParam, { ...dto, romoId });
  }
}
