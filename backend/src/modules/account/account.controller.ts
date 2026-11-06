import { Body, Controller, Delete, HttpCode } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { IsNotEmpty, IsString, MaxLength } from 'class-validator';
import type { AuthUser } from '../../common/access/access.service';
import { AllowInactiveAccount } from '../../common/decorators/allow-inactive.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AccountDeletionService } from './account-deletion.service';

class DeleteAccountDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(128)
  password!: string;
}

@ApiTags('Auth')
@ApiBearerAuth('JWT-auth')
@Controller('auth')
export class AccountController {
  constructor(private readonly deletion: AccountDeletionService) {}

  // Akun yang masih menunggu persetujuan atau ditolak juga berhak menghapus akunnya.
  @AllowInactiveAccount()
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  @Delete('account')
  @HttpCode(200)
  @ApiOperation({
    summary: 'Hapus akun sendiri',
    description:
      'Wajib kata sandi. Data pribadi dianonimkan; ditolak (409) bila masih ada pelayanan yang berjalan.',
  })
  deleteOwnAccount(
    @CurrentUser() user: AuthUser,
    @Body() dto: DeleteAccountDto,
  ) {
    // Identitas hanya dari token.
    return this.deletion.deleteOwnAccount(Number(user.sub), dto.password);
  }
}
