# Stage 1: Build environment
FROM node:22-slim AS builder

WORKDIR /app

# Copy package configuration
COPY package.json package-lock.json* ./

# Install only production dependencies
RUN npm ci --omit=dev

# Copy the rest of the application
COPY . .

# Stage 2: Secure production environment (distroless)
FROM gcr.io/distroless/nodejs22-debian12

WORKDIR /app

# Copy dependencies and code from the builder stage
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/src ./src

# Cloud Run requirement
ENV PORT=8080
EXPOSE 8080

# Start command
CMD ["src/server.js"]