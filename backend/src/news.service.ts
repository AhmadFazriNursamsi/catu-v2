import { Injectable, Logger } from '@nestjs/common';
import { DataSource } from 'typeorm';
import axios from 'axios';

export interface NewsArticleItem {
  id: string;
  sourceId: string;
  sourceName: string;
  sourceCode: string;
  sourceLogo?: string;
  categoryId: string;
  categoryName: string;
  categorySlug: string;
  categoryIcon?: string;
  title: string;
  slug: string;
  summary: string;
  contentHtml: string;
  author: string;
  originalUrl: string;
  imageUrl?: string;
  publishedAt: string;
  scrapedAt: string;
  viewCount: number;
  isFeatured: boolean;
  isEditorsChoice: boolean;
}

@Injectable()
export class NewsService {
  private readonly logger = new Logger(NewsService.name);

  constructor(private readonly dataSource: DataSource) {}

  async onModuleInit() {
    // Initial auto-scrape on startup if empty
    setTimeout(() => {
      this.ensureInitialScrape();
    }, 5000);
  }

  async ensureInitialScrape() {
    try {
      const countRes = await this.dataSource.query('SELECT COUNT(*) FROM news_articles');
      const count = parseInt(countRes[0]?.count || '0', 10);
      if (count === 0) {
        this.logger.log('No articles found in DB. Starting initial scrape...');
        await this.scrapeAll();
      }
    } catch (e) {
      this.logger.error(`Initial scrape check error: ${e.message}`);
    }
  }

  private cleanText(str: string): string {
    if (!str) return '';
    return str
      .replace(/<!\[CDATA\[(.*?)\]\]>/gs, '$1')
      .replace(/<[^>]*>/g, ' ')
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private extractImageUrl(rawContent: string, itemXml: string): string | null {
    // 1. Check enclosure tag
    const encMatch = itemXml.match(/<enclosure[^>]+url=["']([^"']+)["']/i);
    if (encMatch && encMatch[1]) return encMatch[1];

    // 2. Check media:content or media:thumbnail
    const mediaMatch = itemXml.match(/<media:(?:content|thumbnail)[^>]+url=["']([^"']+)["']/i);
    if (mediaMatch && mediaMatch[1]) return mediaMatch[1];

    // 3. Check img tag in content/description
    const imgMatch = rawContent.match(/<img[^>]+src=["']([^"']+)["']/i);
    if (imgMatch && imgMatch[1]) return imgMatch[1];

    return null;
  }

  private categorize(title: string, content: string): string {
    const text = (title + ' ' + content).toLowerCase();
    if (text.includes('paus') || text.includes('vatikan') || text.includes('vatican') || text.includes('bapa suci') || text.includes('roma') || text.includes('sinode')) {
      return 'vatikan-dan-paus';
    }
    if (text.includes('renungan') || text.includes('oase') || text.includes('bacaan harian') || text.includes('injil') || text.includes('homili') || text.includes('sabda')) {
      return 'renungan-oase';
    }
    if (text.includes('liturgi') || text.includes('sakramen') || text.includes('doa') || text.includes('novena') || text.includes('rosario') || text.includes('misa') || text.includes('paskah') || text.includes('natal')) {
      return 'liturgi-dan-doa';
    }
    if (text.includes('omk') || text.includes('orang muda') || text.includes('youth') || text.includes('remaja') || text.includes('mudika')) {
      return 'orang-muda-katolik';
    }
    return 'gereja-indonesia';
  }

  private generateSlug(title: string): string {
    const clean = title
      .toLowerCase()
      .replace(/[^a-z0-9\s-]/g, '')
      .trim()
      .replace(/\s+/g, '-');
    const randomSuffix = Math.floor(1000 + Math.random() * 9000);
    return `${clean.substring(0, 80)}-${randomSuffix}`;
  }

  async scrapeFeed(source: any): Promise<{ inserted: number; skipped: number; total: number }> {
    let inserted = 0;
    let skipped = 0;
    let total = 0;

    const startTime = new Date();
    try {
      this.logger.log(`Scraping source: ${source.name} (${source.feed_url})`);
      const response = await axios.get(source.feed_url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 CATU/1.0',
          'Accept': 'application/rss+xml, application/xml, text/xml, */*',
        },
        timeout: 10000,
      });

      const xml = response.data.toString();
      const itemRegex = /<item>(.*?)<\/item>/gs;
      let match;

      // Get categories map
      const categories = await this.dataSource.query('SELECT id, slug FROM news_categories');
      const catMap = new Map<string, number>();
      for (const cat of categories) {
        catMap.set(cat.slug, parseInt(cat.id, 10));
      }

      while ((match = itemRegex.exec(xml)) !== null) {
        total++;
        const itemXml = match[1];

        const titleMatch = itemXml.match(/<title>(.*?)<\/title>/s);
        const linkMatch = itemXml.match(/<link>(.*?)<\/link>/s);
        const guidMatch = itemXml.match(/<guid[^>]*>(.*?)<\/guid>/s);
        const pubDateMatch = itemXml.match(/<pubDate>(.*?)<\/pubDate>/s);
        const descMatch = itemXml.match(/<description>(.*?)<\/description>/s);
        const contentMatch = itemXml.match(/<content:encoded>(.*?)<\/content:encoded>/s);
        const creatorMatch = itemXml.match(/<dc:creator>(.*?)<\/dc:creator>/s) || itemXml.match(/<author>(.*?)<\/author>/s);

        const rawTitle = titleMatch ? titleMatch[1] : '';
        const title = this.cleanText(rawTitle);
        const rawLink = linkMatch ? linkMatch[1] : '';
        const link = this.cleanText(rawLink);
        const guid = guidMatch ? this.cleanText(guidMatch[1]) : (link || title);

        if (!title || !link) continue;

        const rawDesc = descMatch ? descMatch[1] : '';
        const rawContent = contentMatch ? contentMatch[1] : rawDesc;
        const summary = this.cleanText(rawDesc).substring(0, 300);
        const author = creatorMatch ? this.cleanText(creatorMatch[1]) : source.name;
        
        let publishedAt = new Date();
        if (pubDateMatch) {
          const parsed = new Date(pubDateMatch[1].trim());
          if (!isNaN(parsed.getTime())) publishedAt = parsed;
        }

        const imageUrl = this.extractImageUrl(rawContent, itemXml) || this.getDefaultCatholicImage(source.code);
        const catSlug = this.categorize(title, summary);
        const categoryId = catMap.get(catSlug) || catMap.get('gereja-indonesia') || 1;
        const slug = this.generateSlug(title);

        const cleanHtml = rawContent
          .replace(/<!\[CDATA\[(.*?)\]\]>/gs, '$1')
          .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
          .replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, '')
          .trim();

        // Check if exists
        const exists = await this.dataSource.query('SELECT id FROM news_articles WHERE guid = $1', [guid]);
        if (exists && exists.length > 0) {
          skipped++;
          continue;
        }

        const isFeatured = total <= 2; // Feature the latest 2 items per source

        await this.dataSource.query(
          `INSERT INTO news_articles 
            (source_id, category_id, guid, title, slug, summary, content_html, content_text, author, original_url, image_url, published_at, status, is_featured)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, 'PUBLISHED', $13)
           ON CONFLICT (guid) DO NOTHING`,
          [
            source.id,
            categoryId,
            guid,
            title,
            slug,
            summary,
            cleanHtml || `<p>${summary}</p>`,
            this.cleanText(rawContent),
            author,
            link,
            imageUrl,
            publishedAt,
            isFeatured,
          ],
        );
        inserted++;
      }

      await this.dataSource.query('UPDATE news_sources SET last_scraped_at = CURRENT_TIMESTAMP WHERE id = $1', [source.id]);

      await this.dataSource.query(
        `INSERT INTO news_scrape_logs (source_id, started_at, finished_at, status, items_found, items_inserted, items_skipped)
         VALUES ($1, $2, CURRENT_TIMESTAMP, 'SUCCESS', $3, $4, $5)`,
        [source.id, startTime, total, inserted, skipped],
      );

      return { inserted, skipped, total };
    } catch (err) {
      this.logger.error(`Failed to scrape ${source.name}: ${err.message}`);
      await this.dataSource.query(
        `INSERT INTO news_scrape_logs (source_id, started_at, finished_at, status, items_found, items_inserted, items_skipped, error_log)
         VALUES ($1, $2, CURRENT_TIMESTAMP, 'FAILED', $3, $4, $5, $6)`,
        [source.id, startTime, total, inserted, skipped, err.message],
      );
      return { inserted, skipped, total };
    }
  }

  private getDefaultCatholicImage(sourceCode: string): string {
    const defaultImages = [
      'https://images.unsplash.com/photo-1548625361-195fe578cb26?w=800&auto=format&fit=crop&q=80', // Katedral
      'https://images.unsplash.com/photo-1519817650390-64a93db51149?w=800&auto=format&fit=crop&q=80', // Altar
      'https://images.unsplash.com/photo-1438232992991-995b7058bbb3?w=800&auto=format&fit=crop&q=80', // Cahaya Salib
      'https://images.unsplash.com/photo-1543807535-eceef0bc6599?w=800&auto=format&fit=crop&q=80', // Gereja
    ];
    return defaultImages[Math.floor(Math.random() * defaultImages.length)];
  }

  async scrapeAll(): Promise<{ message: string; results: any[] }> {
    const sources = await this.dataSource.query('SELECT * FROM news_sources WHERE is_active = TRUE');
    const results: any[] = [];

    for (const src of sources) {
      if (src.feed_url) {
        const res = await this.scrapeFeed(src);
        results.push({ source: src.name, ...res });
      }
    }

    return {
      message: 'Scrape completed successfully',
      results,
    };
  }

  async getArticles(filter: {
    categorySlug?: string;
    search?: string;
    page?: number;
    limit?: number;
    sourceCode?: string;
  }) {
    const page = Math.max(1, filter.page || 1);
    const limit = Math.max(1, Math.min(50, filter.limit || 10));
    const offset = (page - 1) * limit;

    let whereSql = `WHERE a.status = 'PUBLISHED'`;
    const params: any[] = [];
    let pIdx = 1;

    if (filter.categorySlug && filter.categorySlug !== 'semua') {
      whereSql += ` AND c.slug = $${pIdx++}`;
      params.push(filter.categorySlug);
    }

    if (filter.sourceCode) {
      whereSql += ` AND s.code = $${pIdx++}`;
      params.push(filter.sourceCode);
    }

    if (filter.search && filter.search.trim().length > 0) {
      whereSql += ` AND (a.title ILIKE $${pIdx} OR a.summary ILIKE $${pIdx} OR a.content_text ILIKE $${pIdx})`;
      params.push(`%${filter.search.trim()}%`);
      pIdx++;
    }

    const countQuery = `
      SELECT COUNT(a.id) as total
      FROM news_articles a
      LEFT JOIN news_sources s ON a.source_id = s.id
      LEFT JOIN news_categories c ON a.category_id = c.id
      ${whereSql}
    `;
    const countRes = await this.dataSource.query(countQuery, params);
    const total = parseInt(countRes[0]?.total || '0', 10);

    const query = `
      SELECT 
        a.id,
        a.source_id as "sourceId",
        s.name as "sourceName",
        s.code as "sourceCode",
        s.logo_url as "sourceLogo",
        a.category_id as "categoryId",
        c.name as "categoryName",
        c.slug as "categorySlug",
        c.icon_name as "categoryIcon",
        a.title,
        a.slug,
        a.summary,
        a.author,
        a.original_url as "originalUrl",
        a.image_url as "imageUrl",
        a.published_at as "publishedAt",
        a.scraped_at as "scrapedAt",
        a.view_count as "viewCount",
        a.is_featured as "isFeatured",
        a.is_editors_choice as "isEditorsChoice"
      FROM news_articles a
      LEFT JOIN news_sources s ON a.source_id = s.id
      LEFT JOIN news_categories c ON a.category_id = c.id
      ${whereSql}
      ORDER BY a.published_at DESC
      LIMIT $${pIdx++} OFFSET $${pIdx++}
    `;
    const items = await this.dataSource.query(query, [...params, limit, offset]);

    // Get Featured articles for top carousel
    const featuredQuery = `
      SELECT 
        a.id,
        a.source_id as "sourceId",
        s.name as "sourceName",
        s.code as "sourceCode",
        c.name as "categoryName",
        c.slug as "categorySlug",
        a.title,
        a.slug,
        a.summary,
        a.author,
        a.original_url as "originalUrl",
        a.image_url as "imageUrl",
        a.published_at as "publishedAt",
        a.view_count as "viewCount"
      FROM news_articles a
      LEFT JOIN news_sources s ON a.source_id = s.id
      LEFT JOIN news_categories c ON a.category_id = c.id
      WHERE a.status = 'PUBLISHED' AND a.image_url IS NOT NULL
      ORDER BY a.is_featured DESC, a.published_at DESC
      LIMIT 5
    `;
    const featuredArticles = await this.dataSource.query(featuredQuery);

    return {
      statusCode: 200,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
      featuredArticles,
      articles: items,
    };
  }

  async getArticleByIdOrSlug(idOrSlug: string) {
    const isId = /^\d+$/.test(idOrSlug);
    const whereClause = isId ? 'a.id = $1' : 'a.slug = $1';

    const query = `
      SELECT 
        a.id,
        a.source_id as "sourceId",
        s.name as "sourceName",
        s.code as "sourceCode",
        s.base_url as "sourceBaseUrl",
        s.logo_url as "sourceLogo",
        a.category_id as "categoryId",
        c.name as "categoryName",
        c.slug as "categorySlug",
        c.icon_name as "categoryIcon",
        a.title,
        a.slug,
        a.summary,
        a.content_html as "contentHtml",
        a.author,
        a.original_url as "originalUrl",
        a.image_url as "imageUrl",
        a.published_at as "publishedAt",
        a.scraped_at as "scrapedAt",
        a.view_count as "viewCount",
        a.is_featured as "isFeatured"
      FROM news_articles a
      LEFT JOIN news_sources s ON a.source_id = s.id
      LEFT JOIN news_categories c ON a.category_id = c.id
      WHERE ${whereClause}
    `;

    const res = await this.dataSource.query(query, [idOrSlug]);
    if (!res || res.length === 0) {
      return null;
    }

    const article = res[0];

    // Increment view count asynchronously
    this.dataSource.query('UPDATE news_articles SET view_count = view_count + 1 WHERE id = $1', [article.id]).catch(() => {});

    // Related articles in same category
    const relatedQuery = `
      SELECT 
        a.id,
        s.name as "sourceName",
        c.name as "categoryName",
        a.title,
        a.slug,
        a.image_url as "imageUrl",
        a.published_at as "publishedAt"
      FROM news_articles a
      LEFT JOIN news_sources s ON a.source_id = s.id
      LEFT JOIN news_categories c ON a.category_id = c.id
      WHERE a.id != $1 AND a.status = 'PUBLISHED' AND a.category_id = $2
      ORDER BY a.published_at DESC
      LIMIT 4
    `;
    const relatedArticles = await this.dataSource.query(relatedQuery, [article.id, article.categoryId]);

    return {
      ...article,
      relatedArticles,
    };
  }

  async getCategories() {
    const query = `
      SELECT 
        c.id,
        c.name,
        c.slug,
        c.description,
        c.icon_name as "iconName",
        c.display_order as "displayOrder",
        COUNT(a.id)::int as "articleCount"
      FROM news_categories c
      LEFT JOIN news_articles a ON a.category_id = c.id AND a.status = 'PUBLISHED'
      WHERE c.is_active = TRUE
      GROUP BY c.id
      ORDER BY c.display_order ASC
    `;
    return this.dataSource.query(query);
  }

  async getSources() {
    const query = `
      SELECT 
        s.id,
        s.name,
        s.code,
        s.base_url as "baseUrl",
        s.logo_url as "logoUrl",
        s.last_scraped_at as "lastScrapedAt",
        COUNT(a.id)::int as "articleCount"
      FROM news_sources s
      LEFT JOIN news_articles a ON a.source_id = s.id AND a.status = 'PUBLISHED'
      WHERE s.is_active = TRUE
      GROUP BY s.id
      ORDER BY s.id ASC
    `;
    return this.dataSource.query(query);
  }

  async searchLiveSearXNG(q: string) {
    if (!q || q.trim().length === 0) return { results: [] };
    const query = q.trim();

    try {
      // Query local SearXNG container
      const searchUrl = `http://catu_searxng:8080/search?q=${encodeURIComponent(query + ' katolik')}&format=json&categories=news`;
      const response = await axios.get(searchUrl, { timeout: 6000 });
      const rawResults = response.data?.results || [];

      const formatted = rawResults.slice(0, 15).map((item: any, idx: number) => ({
        id: `searxng-${idx}`,
        title: item.title,
        summary: item.content || item.snippet || '',
        url: item.url,
        sourceName: item.engine || 'SearXNG News',
        publishedAt: item.publishedDate || new Date().toISOString(),
        imageUrl: item.img_src || item.thumbnail || null,
        isExternal: true,
      }));

      return {
        query,
        count: formatted.length,
        results: formatted,
      };
    } catch (e) {
      this.logger.warn(`SearXNG query failed: ${e.message}. Falling back to internal search.`);
      const fallback = await this.getArticles({ search: query, limit: 15 });
      return {
        query,
        count: fallback.articles.length,
        results: fallback.articles.map((a: any) => ({
          id: a.id,
          title: a.title,
          summary: a.summary,
          url: a.originalUrl,
          sourceName: a.sourceName,
          publishedAt: a.publishedAt,
          imageUrl: a.imageUrl,
          isExternal: false,
        })),
      };
    }
  }
}
