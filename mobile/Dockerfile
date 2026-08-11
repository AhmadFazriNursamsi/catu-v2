# Build Flutter Web secara lokal dan serving dengan Nginx Container
FROM nginx:alpine

# Copy hasil build web lokal ke Nginx server
COPY build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
