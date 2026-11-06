import { Controller, Get, Header } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import { renderPrivacyPage } from './privacy.page';

@ApiTags('Public')
@Controller('public')
export class LegalController {
  @Public()
  @Get('privacy')
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'public, max-age=3600')
  @ApiOperation({ summary: 'Kebijakan privasi (halaman publik untuk App Store / Play Store)' })
  privacy() {
    return renderPrivacyPage({
      controllerName: process.env.PRIVACY_CONTROLLER_NAME,
      contactEmail: process.env.PRIVACY_CONTACT_EMAIL,
    });
  }
}
