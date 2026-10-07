FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./

RUN npm ci

COPY . .

RUN npm run build && npm prune --omit=dev

FROM node:20-alpine AS runner

ENV NODE_ENV=production

WORKDIR /app

COPY --from=builder --chown=node:node /app/package*.json ./
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/drizzle ./drizzle
# Skrip role database hak minimal (tanpa folder db/dev-only yang berisi data development).
COPY --from=builder --chown=node:node /app/db/app-role.sql ./db/app-role.sql
# Firebase credentials are provided at runtime through a secret or volume.
# Direktori unggahan APK lokal harus dapat ditulis oleh user non-root.
RUN mkdir -p /app/public && chown node:node /app/public

USER node

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${PORT:-3000}/health" > /dev/null || exit 1

CMD ["node", "dist/main.js"]
