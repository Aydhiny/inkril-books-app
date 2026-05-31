# Decrypting the environment file

The project secrets are in `env.enc` (attached to the GitHub release).

**Decrypt with the password provided separately:**

```bash
openssl enc -d -aes-256-cbc -pbkdf2 -in env.enc -out .env -pass pass:<PASSWORD>
```

Then place the resulting `.env` file in the project root and run:

```bash
docker compose up -d --build
```

The API will be available on port `8080`. Seed data (including test accounts) is
applied automatically on first startup.

**Test credentials**

| Role    | Username | Password |
|---------|----------|----------|
| Admin   | desktop  | test     |
| Mobile  | mobile   | test     |
