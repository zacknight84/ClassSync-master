# ─────────────────────────────────────────────────────────────
# Stage 1: Install dependencies
# ─────────────────────────────────────────────────────────────
FROM node:20-alpine AS deps

# Install libc6-compat for native binaries (Prisma query engine)
RUN apk add --no-cache libc6-compat openssl

WORKDIR /app

# Copy package files first for layer caching
COPY package.json package-lock.json* ./
COPY prisma/schema.prisma ./prisma/schema.prisma

# Install ALL dependencies (including devDeps needed for build)
RUN npm ci

# Generate Prisma client (needs schema + node_modules)
RUN npx prisma generate


# ─────────────────────────────────────────────────────────────
# Stage 2: Build the Next.js application
# ─────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

RUN apk add --no-cache libc6-compat openssl

WORKDIR /app

# Copy installed deps from previous stage
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/node_modules/.prisma ./node_modules/.prisma

# Copy all source files
COPY . .

# Provide dummy DB URLs so Next.js build doesn't fail on env validation
# (actual values are injected at runtime via docker-compose / Railway / Fly.io)
ENV DATABASE_URL="postgresql://dummy:dummy@dummy:5432/dummy"
ENV DIRECT_URL="postgresql://dummy:dummy@dummy:5432/dummy"
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production

# Build the Next.js app (outputs to .next/standalone for minimal image)
RUN npm run build


# ─────────────────────────────────────────────────────────────
# Stage 3: Production runner (minimal image)
# ─────────────────────────────────────────────────────────────
FROM node:20-alpine AS runner

RUN apk add --no-cache libc6-compat openssl curl

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Create a non-root user for security
RUN addgroup --system --gid 1001 nodejs \
    && adduser --system --uid 1001 nextjs

# Copy standalone Next.js build (self-contained, no node_modules needed)
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

# Copy Prisma schema + generated client for runtime migrations
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma

# Copy the migration entrypoint script
COPY docker-entrypoint.sh ./docker-entrypoint.sh
RUN chmod +x ./docker-entrypoint.sh

# Set correct ownership for security
RUN chown -R nextjs:nodejs /app

# Run as non-root user
USER nextjs

EXPOSE 3000

# Healthcheck: ping the Next.js app every 30s
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3000/api/teachers || exit 1

# Entrypoint runs prisma migrate deploy then starts the app
ENTRYPOINT ["./docker-entrypoint.sh"]
