FROM node:20-alpine

ARG NODE_ENV=production

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .

RUN if [ "$NODE_ENV" = "production" ]; then \
      sed -i '/AGENTATION_START/,/AGENTATION_END/d' /app/index.html; \
      sed -i '/AGENTATION_CSS_START/,/AGENTATION_CSS_END/d' /app/css/styles.css; \
      rm -f /app/js/services/agentation.js; \
    fi

EXPOSE 80

CMD ["sh", "-c", "set -eu; test -n \"$PUBLIC_API_URL\" || { echo 'PUBLIC_API_URL must be configured for the Admin Web container' >&2; exit 1; }; test -n \"$PUBLIC_APK_URL\" || { echo 'PUBLIC_APK_URL must be configured for the Admin Web container' >&2; exit 1; }; node -e 'const fs = require(\"fs\"); const config = { nodeEnv: process.env.NODE_ENV || \"production\", apiBaseUrl: process.env.PUBLIC_API_URL, apkDownloadUrl: process.env.PUBLIC_APK_URL }; fs.writeFileSync(\"/app/js/runtime-config.js\", `window.CATU_RUNTIME_CONFIG = ${JSON.stringify(config)};\\n`);'; exec npm run start"]
