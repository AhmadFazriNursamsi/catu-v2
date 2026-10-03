import { Controller, Get, Post, Query, Param, NotFoundException } from '@nestjs/common';
import { NewsService } from './news.service';
import { Roles } from './common/decorators/roles.decorator';
import { Public } from './common/decorators/public.decorator';
import { ADMIN_ROLES } from './common/access/role-groups';

@Controller('news')
export class NewsController {
  constructor(private readonly newsService: NewsService) {}

  @Public()
  @Get()
  async getArticles(
    @Query('categorySlug') categorySlug?: string,
    @Query('search') search?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('sourceCode') sourceCode?: string,
  ) {
    return this.newsService.getArticles({
      categorySlug,
      search,
      page: page ? parseInt(page, 10) : 1,
      limit: limit ? parseInt(limit, 10) : 10,
      sourceCode,
    });
  }

  @Public()
  @Get('categories')
  async getCategories() {
    return this.newsService.getCategories();
  }

  @Public()
  @Get('sources')
  async getSources() {
    return this.newsService.getSources();
  }

  @Public()
  @Get('search-live')
  async searchLive(@Query('q') q: string) {
    return this.newsService.searchLiveSearXNG(q);
  }

  @Roles(...ADMIN_ROLES)
  @Post('scrape/run')
  async triggerScrape() {
    return this.newsService.scrapeAll();
  }

  @Public()
  @Get(':idOrSlug')
  async getArticle(@Param('idOrSlug') idOrSlug: string) {
    const article = await this.newsService.getArticleByIdOrSlug(idOrSlug);
    if (!article) {
      throw new NotFoundException('Artikel berita tidak ditemukan');
    }
    return article;
  }
}
