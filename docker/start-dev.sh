#!/bin/bash

# Development startup script for Arduino Sensor Data Processor
# This script provides more verbose logging and development-friendly features

set -e

echo "🚀 Starting Arduino Sensor Data Processor (Development)"
echo "======================================================"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if serial port exists
check_serial_port() {
    local port="${SERIAL_PORT:-/dev/ttyUSB0}"
    
    log "🔍 Checking serial port: $port"
    
    if [ -e "$port" ]; then
        log "✅ Serial port $port found"
        log "📊 Port details:"
        ls -la "$port" 2>/dev/null || true
        return 0
    else
        log "⚠️  Serial port $port not found"
        log "📋 Available serial devices:"
        find /dev -name "tty*" -type c 2>/dev/null | head -20 || log "No serial devices found"
        log "💡 For development, you can:"
        log "   1. Connect Arduino and check the correct port"
        log "   2. Use the serial simulator: python serial_test_simulator.py"
        log "   3. Test with HTTP POST requests only"
        return 1
    fi
}

# Function to validate environment variables
validate_environment() {
    log "🔍 Validating environment variables..."
    
    # Show current environment (excluding sensitive data)
    log "📊 Current environment:"
    env | grep -E "^(FLASK_|SERIAL_|DEBUG|SMS_)" | sed 's/=.*/=***/' || true
    
    local required_vars=("GEMINI_API_KEY")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log "❌ Missing required environment variables: ${missing_vars[*]}"
        log "💡 Create a .env file with the required variables"
        log "📝 Example .env file:"
        log "   GEMINI_API_KEY=your_api_key_here"
        log "   SERIAL_PORT=/dev/ttyUSB0"
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
    touch /app/logs/flask-dev-supervisor.log
    touch /app/logs/serial-dev-supervisor.log
    
    # More permissive permissions for development
    chmod 755 /app/logs
    chmod 666 /app/logs/*.log
    
    log "✅ Directories created with development permissions"
}

# Function to show development information
show_dev_info() {
    log "🔧 Development Information:"
    log "   Flask Debug Mode: ${FLASK_DEBUG:-1}"
    log "   Flask Environment: ${FLASK_ENV:-development}"
    log "   Hot Reload: Enabled"
    log "   Serial Port: ${SERIAL_PORT:-/dev/ttyUSB0}"
    log "   Forward to Flask: ${FORWARD_TO_FLASK:-True}"
    log ""
    log "🌐 Access URLs:"
    log "   Flask Server: http://localhost:5000"
    log "   Health Check: http://localhost:5000/health"
    log "   SMS Status: http://localhost:5000/sms/status"
    log ""
    log "🧪 Testing Commands:"
    log "   Test API: curl -X GET http://localhost:5000/health"
    log "   Test SMS: curl -X POST http://localhost:5000/sms/test"
    log "   Serial Sim: python serial_test_simulator.py --test"
}

# Function to run health checks
health_check() {
    log "🏥 Running development health checks..."
    
    # Check Python modules
    log "🐍 Checking Python dependencies..."
    python -c "
import sys
modules = ['serial', 'requests', 'google.generativeai', 'africastalking', 'flask']
for module in modules:
    try:
        __import__(module)
        print(f'✅ {module}')
    except ImportError as e:
        print(f'❌ {module}: {e}')
        sys.exit(1)
" || {
        log "❌ Python dependencies check failed"
        exit 1
    }
    
    log "✅ All dependencies available"
}

# Function to start development services
start_services() {
    log "🎯 Starting development services with Supervisor..."
    log "📝 Logs will be available in /app/logs/"
    log "🔄 Services will auto-restart on file changes"
    
    # Start supervisor in development mode
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
}

# Main startup sequence
main() {
    log "Starting development initialization sequence..."
    
    # Validate environment
    validate_environment
    
    # Setup directories
    setup_directories
    
    # Run health checks
    health_check
    
    # Show development information
    show_dev_info
    
    # Check serial port (non-blocking)
    if ! check_serial_port; then
        log "⚠️  Serial port not available in development mode"
        log "🔧 Development options:"
        log "   1. Use serial simulator for testing"
        log "   2. Connect Arduino and restart container"
        log "   3. Test Flask API directly with HTTP requests"
    fi
    
    # Start services
    start_services
}

# Trap signals for graceful shutdown
trap 'log "🛑 Received shutdown signal, stopping development services..."; exit 0' SIGTERM SIGINT

# Run main function
main "$@"