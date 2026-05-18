# ─── Telegram Bot Dockerfile for Choreo (WSO2 Developer Platform) ───
# Build: Dockerfile approach (BYOC - Bring Your Own Container)
# Component Type: Service (for 24/7 uptime with healthchecks)
# ─────────────────────────────────────────────────────────────────────

FROM python:3.11-slim

# Prevent Python from writing .pyc files and enable unbuffered stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install system dependencies required by the bot
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user (Choreo requires UID between 10000-20000)
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -m appuser

# Set working directory
WORKDIR /app

# Copy requirements first for better Docker layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY . .

# Choreo sets the PORT environment variable automatically.
# The bot's healthcheck server reads PORT and listens on it.
# Default to 8080 if not set (for local testing).
ENV PORT=8080

# Switch to non-root user (required by Choreo)
USER 10001

# Expose the healthcheck port
EXPOSE 8080

# Health check — hits the bot's /health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" || exit 1

# Run the bot
CMD ["python", "main.py"]
