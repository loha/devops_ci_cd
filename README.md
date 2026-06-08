# Dockerized Django + PostgreSQL + Nginx

A Django web application containerized with Docker Compose, backed by PostgreSQL
and served through Nginx as a reverse proxy.

## Stack

- **web** — Django application (served by Gunicorn)
- **db** — PostgreSQL database
- **nginx** — reverse proxy listening on port 80, forwards requests to Django and serves static files

## Prerequisites

- Docker
- Docker Compose (bundled with Docker Desktop, or the `docker compose` plugin)

## Configuration

Environment variables are loaded from a `.env` file. Copy the example file and adjust if needed:

```bash
cp .env.example .env
```

## Running the project

Build the images and start all services in the background:

```bash
docker-compose up -d
```

Docker Compose will:

1. Build the `web` image from the [Dockerfile](Dockerfile) and install dependencies from [requirements.txt](requirements.txt).
2. Start PostgreSQL and wait until it reports healthy.
3. Run Django migrations, collect static files, and start the app with Gunicorn.
4. Start Nginx, which proxies incoming requests on port 80 to the Django app.

## Verifying it works

- Open **http://localhost** in a browser — you should see the Django welcome page served through Nginx.
- Check that the database connection works (migrations are applied automatically on startup):

```bash
docker-compose exec db psql -U app_user -d app_db -c "\dt"
```

You should see Django's tables (`auth_user`, `django_migrations`, `django_session`, etc.).

## Useful commands

```bash
# View logs for a specific service
docker-compose logs -f web

# Run Django management commands inside the web container
docker-compose exec web python manage.py <command>

# Stop all services
docker-compose down

# Stop all services and remove volumes (database data, static files)
docker-compose down -v
```
