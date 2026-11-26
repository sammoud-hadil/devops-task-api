# syntax=docker/dockerfile:1
# Multi-stage build. The Python runtime version is a build argument so the
# pipelines can build several runtimes in parallel (3.11 and 3.12).
ARG PYTHON_VERSION=3.12

# ---------- Stage 1: build wheels for the dependencies ----------
FROM python:${PYTHON_VERSION}-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

# ---------- Stage 2: run unit tests (used with --target test) ----------
FROM python:${PYTHON_VERSION}-slim AS test
WORKDIR /app
COPY requirements.txt requirements-dev.txt ./
RUN pip install --no-cache-dir -r requirements-dev.txt
COPY app ./app
COPY tests ./tests
RUN python -m pytest -q tests

# ---------- Stage 3: small runtime image ----------
FROM python:${PYTHON_VERSION}-slim AS runtime
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION} \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /app
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir /wheels/* && rm -rf /wheels \
    && useradd --create-home appuser
COPY app ./app
USER appuser
EXPOSE 5000
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "1", "--threads", "4", "app.main:app"]
