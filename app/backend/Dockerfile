# etape 1 : installer les dependances
FROM node:20-alpine AS deps

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# etape 2 : image finale legere
FROM node:20-alpine AS production

# on cree un user non-root pour la securite
RUN addgroup -g 1001 -S nodejs \
 && adduser  -S nodeuser -u 1001 -G nodejs

WORKDIR /app

# on copie que les deps de prod
COPY --from=deps --chown=nodeuser:nodejs /app/node_modules ./node_modules

# copie du code
COPY --chown=nodeuser:nodejs src/     ./src/
COPY --chown=nodeuser:nodejs package.json ./

# on passe en non-root
USER nodeuser

EXPOSE 3000

# healthcheck docker
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO- http://localhost:3000/api/health || exit 1

CMD ["node", "src/index.js"]
