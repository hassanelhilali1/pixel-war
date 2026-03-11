# etape 1 : build de l'app react
FROM node:20-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY . .
ARG VITE_GRID_SIZE=50
ENV VITE_GRID_SIZE=$VITE_GRID_SIZE
RUN npm run build

# etape 2 : on sert les fichiers avec nginx
FROM nginx:1.25-alpine AS production

RUN rm /etc/nginx/conf.d/default.conf

# copie des fichiers buildes
COPY --from=builder /app/dist /usr/share/nginx/html

# config nginx custom
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
