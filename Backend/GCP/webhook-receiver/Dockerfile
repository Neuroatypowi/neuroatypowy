# == ETAP 1: Budowanie aplikacji ==
FROM node:22-slim AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY . .

# == ETAP 2: Bezpieczny obraz produkcyjny ==
# Obraz "distroless" nie ma powloki ani narzedzi — trudniejszy do ataku.
FROM gcr.io/distroless/nodejs22-debian12
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/src ./src
ENV PORT=8080
EXPOSE 8080
CMD ["src/server.js"]
