# ── Stage 1 : Installation des dépendances ────────────────────────────────────
FROM node:20-alpine AS deps

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# ── Stage 2 : Image de production (non-root) ──────────────────────────────────
FROM node:20-alpine AS production

# Sécurité : utilisateur non-root dédié
RUN addgroup -g 1001 -S nodejs \
 && adduser  -S nodeuser -u 1001 -G nodejs

WORKDIR /app

# Copier uniquement les dépendances de production
COPY --from=deps --chown=nodeuser:nodejs /app/node_modules ./node_modules

# Copier le code source
COPY --chown=nodeuser:nodejs src/     ./src/
COPY --chown=nodeuser:nodejs package.json ./

# Basculer en utilisateur non-root
USER nodeuser

EXPOSE 3000

# Healthcheck natif Docker
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO- http://localhost:3000/api/health || exit 1

CMD ["node", "src/index.js"]
