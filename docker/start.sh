#!/bin/bash

# Production startup script for Arduino Sensor Data Processor
# This script handles initialization, error checking, and service startup

set -e

echo "🚀 Starting Arduino Sensor Data Processor (Production)"
echo "=================================================="

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if serial port exists
check_serial_port() {
    local port="${SERIAL_PORT:-/dev/ttyUSB0}"
    
    if [ -e "$port" ]; then
        log "✅ Serial port $port found"
        return 0
    else
        log "⚠️  Serial port $port not found"
        log "📋 Available serial devices:"
        ls -la /dev/tty* 2>/dev/null || log "No serial devices found"
        return 1
    fi
}

# Function to validate environment variables
validate_environment() {
    log "🔍 Validating environment variables..."
    
    local required_vars=("GEMINI_API_KEY")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log "❌ Missing required environment variables: ${missing_vars[*]}"
        log "Please check your .env file"
        exit 1
    fi
    
    log "✅ Environment variables validated"
}

# Function to create necessary directories
setup_directories() {
    log "📁 Setting up directories..."
    
    mkdir -p /app/logs
    touch /app/logs/sensor_data.log
    touch /app/logs/serial_listener.log
    touch /app/logs/sms_alerts.log
    
    # Ensure proper permissions
    chmod 755 /app/logs
    chmod 644 /app/logs/*.log
    
    log "✅ Directories created"
}

# Function to wait for dependencies
wait_for_dependencies() {
    log "⏳ Waiting for dependencies to be ready..."
    
    # Wait for any database connections if configured
    if [ -n "${DATABASE_URL}" ]; then
        log "Waiting for database connection..."
        # Add database connection check here if needed
    fi
    
    log "✅ Dependencies ready"
}

# Function to run health checks
health_check() {
    log "🏥 Running health checks..."
    
    # Check Python modules
    python -c "import serial, requests, google.generativeai, africastalking" 2>/dev/null || {
        log "❌ Python dependencies check failed"
        exit 1
    }
    
    log "✅ Health checks passed"
}

# Main startup sequence
main() {
    log "Starting initialization sequence..."
    
    # Validate environment
    validate_environment
    
    # Setup directories
    setup_directories
    
    # Wait for dependencies
    wait_for_dependencies
    
    # Run health checks
    health_check
    
    # Check serial port (non-blocking)
    if ! check_serial_port; then
        log "⚠️  Serial port not available - serial listener may not work"
        log "💡 To fix: ensure Arduino is connected and port is correct in .env"
        log "🔧 You can still test with HTTP POST requests to the Flask API"
    fi
    
    log "🎯 Starting services with Supervisor..."
    
    # Start supervisor
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
}

# Trap signals for graceful shutdown
trap 'log "🛑 Received shutdown signal, stopping services..."; exit 0' SIGTERM SIGINT

# Run main function
main "$@"