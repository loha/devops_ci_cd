# syntax=docker/dockerfile:1
# Multi-stage build for a Django application served by Gunicorn.
FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# System dependencies (build tools for psycopg, then removed).
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies first for better layer caching.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt gunicorn

# Application source.
COPY . .

# Run as a non-root user.
RUN useradd --create-home appuser \
    && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# Collect static files at build time (ignore failure if not configured).
RUN python manage.py collectstatic --noinput || true

# Start the app. Replace "app.wsgi" with your project's WSGI module.
CMD ["gunicorn", "app.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
