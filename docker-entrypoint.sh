#!/bin/sh
# docker-entrypoint.sh
# Runs Prisma migrations then starts the Next.js server

set -e

echo "🔄 Running Prisma migrations..."
# Use DIRECT_URL for migrations (bypasses PgBouncer transaction limits)
npx prisma migrate deploy

echo "🚀 Starting Next.js server..."
exec node server.js
