# ── Stage 1 : Build React ─────────────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY . .
# Inject build-time variables if needed
ARG VITE_GRID_SIZE=50
ENV VITE_GRID_SIZE=$VITE_GRID_SIZE
RUN npm run build

# ── Stage 2 : Nginx de production (~25 MB) ────────────────────────────────────
FROM nginx:1.25-alpine AS production

# Supprimer la config par défaut
RUN rm /etc/nginx/conf.d/default.conf

# Copier les assets buildés
COPY --from=builder /app/dist /usr/share/nginx/html

# Config Nginx personnalisée
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
