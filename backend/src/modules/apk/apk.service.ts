import { readFileSync } from 'node:fs';
import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { GetObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

interface SensioEnvPayload {
  data?: Record<string, unknown>;
}

interface ApkStorageConfig {
  client: S3Client;
  bucket: string;
  objectKey: string;
  expiresIn: number;
  expiresAt: number;
}

@Injectable()
export class ApkService {
  private readonly logger = new Logger(ApkService.name);
  private cachedConfig: ApkStorageConfig | null = null;

  constructor(private readonly configService: ConfigService) {}

  async createDownloadUrl(): Promise<string> {
    try {
      const config = await this.getStorageConfig();
      const command = new GetObjectCommand({
        Bucket: config.bucket,
        Key: config.objectKey,
        ResponseContentType: 'application/vnd.android.package-archive',
        ResponseContentDisposition: 'attachment; filename="CATU.apk"',
      });

      return await getSignedUrl(config.client, command, {
        expiresIn: config.expiresIn,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'unknown error';
      this.logger.error(`Unable to create APK download URL: ${message}`);
      throw new ServiceUnavailableException('APK download is temporarily unavailable');
    }
  }

  private async getStorageConfig(): Promise<ApkStorageConfig> {
    if (this.cachedConfig && this.cachedConfig.expiresAt > Date.now()) {
      return this.cachedConfig;
    }

    const env = await this.fetchSensioEnv();
    const accessKeyId = this.getValue(env, 'S3_ACCESS_KEY_ID', 'AWS_ACCESS_KEY_ID');
    const secretAccessKey = this.getValue(env, 'S3_SECRET_ACCESS_KEY', 'AWS_SECRET_ACCESS_KEY');
    const bucket = this.getValue(env, 'S3_BUCKET', 'AWS_S3_BUCKET');
    const region = this.getValue(env, 'S3_REGION', 'AWS_REGION');
    const objectKey = this.requireConfig('APK_S3_OBJECT_KEY');

    if (!accessKeyId || !secretAccessKey || !bucket || !region || !objectKey) {
      throw new Error('S3 credentials, bucket, region, and APK object key are required');
    }

    const endpoint = this.getValue(env, 'S3_ENDPOINT', 'AWS_S3_ENDPOINT');
    const client = new S3Client({
      region,
      credentials: { accessKeyId, secretAccessKey },
      ...(endpoint ? { endpoint } : {}),
      forcePathStyle: this.toBoolean(env.S3_FORCE_PATH_STYLE),
    });

    const expiresIn = this.getIntegerConfig('APK_DOWNLOAD_URL_TTL_SECONDS', 300, 60, 604800);
    const cacheTtlSeconds = this.getIntegerConfig('SENSIO_ENV_CONFIG_CACHE_TTL_SECONDS', 60, 5, 3600);
    this.cachedConfig = {
      client,
      bucket,
      objectKey,
      expiresIn,
      expiresAt: Date.now() + cacheTtlSeconds * 1000,
    };

    return this.cachedConfig;
  }

  private async fetchSensioEnv(): Promise<Record<string, unknown>> {
    const baseUrl = this.requireConfig('SENSIO_ENV_CONFIG_URL');
    const workspaceId = this.requireConfig('SENSIO_ENV_CONFIG_WORKSPACE_ID');
    const projectId = this.requireConfig('SENSIO_ENV_CONFIG_PROJECT_ID');
    const token = this.readConfigToken();
    const endpoint = [
      baseUrl.replace(/\/+$/, ''),
      'api/internal/workspaces',
      encodeURIComponent(workspaceId),
      'projects',
      encodeURIComponent(projectId),
      'env',
    ].join('/');
    const abortController = new AbortController();
    const timeout = setTimeout(() => abortController.abort(), 10000);

    try {
      const response = await fetch(endpoint, {
        headers: {
          Accept: 'application/json',
          Authorization: `Bearer ${token}`,
        },
        signal: abortController.signal,
      });

      if (!response.ok) {
        throw new Error(`Sensio Env returned HTTP ${response.status}`);
      }

      const payload = (await response.json()) as SensioEnvPayload;
      if (!payload.data || typeof payload.data !== 'object') {
        throw new Error('Sensio Env returned an invalid configuration payload');
      }

      return payload.data;
    } finally {
      clearTimeout(timeout);
    }
  }

  private readConfigToken(): string {
    const tokenFile = this.configService.get<string>('SENSIO_ENV_CONFIG_TOKEN_FILE');
    if (tokenFile) {
      try {
        const token = readFileSync(tokenFile, 'utf8').trim();
        if (token) return token;
      } catch (error) {
        const message = error instanceof Error ? error.message : 'unknown error';
        this.logger.warn(`Unable to read Sensio Env token file: ${message}`);
      }
    }

    const token = this.configService.get<string>('SENSIO_ENV_CONFIG_TOKEN')?.trim();
    if (!token) {
      throw new Error('Sensio Env access token is not configured');
    }

    return token;
  }

  private requireConfig(name: string): string {
    const value = this.configService.get<string>(name)?.trim();
    if (!value) {
      throw new Error(`${name} is not configured`);
    }
    return value;
  }

  private getValue(values: Record<string, unknown>, primary: string, fallback: string): string {
    const primaryValue = this.asString(values[primary]);
    return primaryValue || this.asString(values[fallback]);
  }

  private asString(value: unknown): string {
    return typeof value === 'string' ? value.trim() : '';
  }

  private toBoolean(value: unknown): boolean {
    return value === true || this.asString(value).toLowerCase() === 'true';
  }

  private getIntegerConfig(name: string, fallback: number, minimum: number, maximum: number): number {
    const parsed = Number.parseInt(this.configService.get<string>(name) || '', 10);
    if (Number.isNaN(parsed)) return fallback;
    return Math.min(Math.max(parsed, minimum), maximum);
  }
}
