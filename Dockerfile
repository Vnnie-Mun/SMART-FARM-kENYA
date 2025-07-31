# Production Dockerfile for Arduino Sensor Data Processor
FROM python:3.11-slim

# Set metadata
LABEL maintainer="Arduino Sensor Team"
LABEL description="Arduino Sensor Data Processor with Gemini AI and SMS Alerts"
LABEL version="2.0.0"

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV FLASK_APP=app.py
ENV FLASK_ENV=production

# Create app user (security best practice)
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libc6-dev \
    supervisor \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (for better Docker layer caching)
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p /app/logs /var/log/supervisor && \
    touch /app/logs/sensor_data.log \
    /app/logs/serial_listener.log \
    /app/logs/sms_alerts.log

# Copy supervisor configuration
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy startup script
COPY docker/start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Change ownership to app user
RUN chown -R appuser:appuser /app /var/log/supervisor

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Expose Flask port
EXPOSE 5000

# Default command
CMD ["/app/start.sh"]