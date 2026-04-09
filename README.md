# Inkril 📚

> Gamified book reading platform — daily streaks, leaderboards, PDF reader, personalized recommendations.

**Student:** Ajdin Mehmedović | **Index:** IB220088  
**Course:** Razvoj softvera II — FIT Mostar

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend API | ASP.NET Core 8, Clean Architecture, MediatR, EF Core |
| Worker | .NET 8 Worker Service, RabbitMQ consumer |
| Message Broker | RabbitMQ |
| Database | PostgreSQL (DB name: `220088`) |
| Cache | Redis |
| Mobile App | Flutter (Dart) — Riverpod, GoRouter, Dio |
| Desktop App | Flutter (Dart) — admin panel |
| Auth | JWT Bearer tokens + Refresh tokens |
| Containerization | Docker + Docker Compose |

---

## Prerequisites

- Docker Desktop (≥ 24)
- .NET 8 SDK (for local dev without Docker)
- Flutter SDK ≥ 3.19

---

## Environment Setup

Copy the example file and fill in your values before starting anything:

```bash
cp .env.example .env
```

### Backend variables (used by Docker Compose + dotnet run)

| Variable | Description | Example |
|----------|-------------|---------|
| `POSTGRES_DB` | Database name (must match index number) | `220088` |
| `POSTGRES_USER` | PostgreSQL username | `inkril` |
| `POSTGRES_PASSWORD` | PostgreSQL password — **change this** | `strongpassword` |
| `JWT_KEY` | JWT signing secret — **min 32 characters** | `my-super-secret-key-32-chars!!` |
| `JWT_ISSUER` | Token issuer claim | `inkril-api` |
| `JWT_AUDIENCE` | Token audience claim | `inkril-clients` |
| `JWT_EXPIRY_MINUTES` | Access token lifetime | `60` |
| `JWT_REFRESH_EXPIRY_DAYS` | Refresh token lifetime | `7` |
| `RABBITMQ_HOST` | RabbitMQ hostname (Docker service name) | `rabbitmq` |
| `RABBITMQ_USERNAME` | RabbitMQ username | `inkril` |
| `RABBITMQ_PASSWORD` | RabbitMQ password — **change this** | `strongpassword` |
| `SMTP_HOST` | SMTP server for outgoing email | `smtp.gmail.com` |
| `SMTP_PORT` | SMTP port | `587` |
| `SMTP_USERNAME` | SMTP login | `you@gmail.com` |
| `SMTP_PASSWORD` | SMTP password / app password | `apppassword` |
| `REDIS_HOST` | Redis hostname (Docker service name) | `redis` |
| `REDIS_PASSWORD` | Redis password | `strongpassword` |
| `API_PORT` | Port the API listens on | `8080` |

> When running **without Docker**, set `DB_HOST=localhost`, `RABBITMQ_HOST=localhost`, `REDIS_HOST=localhost`
> and export the variables in your shell or use `appsettings.Development.json`.

### Flutter (mobile & desktop)

Flutter apps do **not** read `.env` — the API URL is injected at build time via `--dart-define`:

```bash
# Android emulator (10.0.2.2 routes to host machine localhost)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080

# iOS simulator / physical device on the same network
flutter run --dart-define=API_BASE_URL=http://192.168.1.x:8080

# Desktop (Windows/macOS/Linux)
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8080
```

Never hardcode the URL in Dart source — it is read from `AppConfig.apiBaseUrl` which is wired to the `--dart-define` value.

---

## Running with Docker (recommended)

```bash
# 1. Clone the repo
git clone <repo-url> && cd inkril-books-app

# 2. Copy and configure environment
cp .env.example .env
# Edit .env — at minimum change passwords

# 3. Start all services
docker compose up -d

# API:     http://localhost:8080
# RabbitMQ Management: http://localhost:15672  (inkril / see .env)
# Swagger: http://localhost:8080/swagger
```

---

## Running Locally (without Docker)

### Backend API

```bash
cd backend/src/Inkril.API
dotnet restore
dotnet run
# Runs on https://localhost:5001
```

### Notification Worker

```bash
cd backend/src/Inkril.NotificationWorker
dotnet restore
dotnet run
```

### Apply Migrations

```bash
cd backend/src/Inkril.API
dotnet ef database update
```

---

## Running Flutter Apps

### Mobile App

```bash
cd mobile
flutter pub get

# Development (local API)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080

# Production
flutter run --dart-define=API_BASE_URL=https://api.inkril.app
```

### Desktop App (Admin)

```bash
cd desktop
flutter pub get

flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8080
# or: -d linux / -d macos
```

---

## Test Credentials

| Role | Username | Password |
|------|---------|---------|
| Admin (Desktop) | `desktop` | `test` |
| User (Mobile) | `mobile` | `test` |

---

## Project Structure

```
inkril-books-app/
├── backend/               # .NET microservices
│   ├── src/
│   │   ├── Inkril.Domain/         # Entities, value objects
│   │   ├── Inkril.Application/    # CQRS, interfaces, business logic
│   │   ├── Inkril.Infrastructure/ # EF Core, RabbitMQ, email
│   │   ├── Inkril.API/            # REST API, controllers, middleware
│   │   └── Inkril.NotificationWorker/  # Async worker microservice
│   ├── Dockerfile.api
│   ├── Dockerfile.worker
│   └── docker-compose.yml
├── mobile/                # Flutter mobile (user-facing)
├── desktop/               # Flutter desktop (admin)

└── .env.example
```

---

## API Endpoints Overview

| Resource | Endpoint |
|---------|---------|
| Auth | `POST /api/auth/login`, `POST /api/auth/register` |
| Books | `GET/POST /api/books`, `PUT/DELETE /api/books/{id}` |
| Users | `GET /api/users`, `PUT /api/users/{id}/status` |
| Leaderboard | `GET /api/leaderboard` |
| Friends | `GET/POST /api/friends`, `POST /api/friends/requests` |
| Notifications | `GET /api/notifications`, `PUT /api/notifications/{id}/read` |
| Recommendations | `GET /api/recommendations` |
| Reports | `GET /api/reports/dashboard` |

Full interactive docs available at `/swagger` when running.
