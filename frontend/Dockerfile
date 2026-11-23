# syntax=docker/dockerfile:1

# Stage 1: install packages and build
FROM node:24-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
ARG API_URL=http://backend:3000
RUN npm run build

# Stage 2: only the built server, no node_modules or source code
FROM node:24-slim
WORKDIR /app
ENV NODE_ENV=production PORT=8000
COPY --from=build /app/.output ./.output
USER node
EXPOSE 8000
CMD ["node", ".output/server/index.mjs"]