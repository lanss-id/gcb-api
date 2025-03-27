# Dockerfile untuk NestJS API di monorepo

# Base build stage
FROM node:18-alpine AS base
WORKDIR /app
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable
COPY . .

# Development dependencies stage
FROM base AS dev-deps
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile

# Production dependencies stage
FROM base AS prod-deps
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --prod --frozen-lockfile

# Build stage
FROM base AS builder
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile
RUN pnpm run build

# Development stage - hot reloading
FROM base AS development
WORKDIR /app
COPY --from=dev-deps /app/node_modules ./node_modules
COPY . .
EXPOSE 3001
CMD ["pnpm", "run", "--filter", "api", "dev"]

# Production stage
FROM node:18-alpine AS production
WORKDIR /app
ENV NODE_ENV production

# Copy necessary files
COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=builder /app/apps/api/dist ./apps/api/dist
COPY --from=builder /app/packages/db/dist ./packages/db/dist
COPY --from=builder /app/packages/validators/dist ./packages/validators/dist
COPY --from=builder /app/packages/config/dist ./packages/config/dist

# Package.json files required for module resolution
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/apps/api/package.json ./apps/api/package.json
COPY --from=builder /app/packages/db/package.json ./packages/db/package.json
COPY --from=builder /app/packages/validators/package.json ./packages/validators/package.json
COPY --from=builder /app/packages/config/package.json ./packages/config/package.json

EXPOSE 3001
CMD ["node", "apps/api/dist/main.js"]
