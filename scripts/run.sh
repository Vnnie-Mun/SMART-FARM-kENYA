#!/bin/bash

# Run script for Arduino Sensor Data Processor Docker containers
# Handles serial port detection, environment setup, and container management

set -e

# Configuration
IMAGE_NAME="arduino-sensor-processor"
CONTAINER_NAME="arduino-sensor-processor"
DEFAULT_PORT="5000"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log with colors
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS] COMMAND"
    echo ""
    echo "Commands:"
    echo "  start        Start the container"
    echo "  stop         Stop the container"
    echo "  restart      Restart the container"
    echo "  logs         Show container logs"
    echo "  shell        Open shell in running container"
    echo "  status       Show container status"
    echo "  cleanup      Remove stopped containers and unused images"
    echo ""
    echo "Options:"
    echo "  -e, --env-file FILE    Environment file (default: .env)"
    echo "  -p, --port PORT        Host port mapping (default: $DEFAULT_PORT)"
    echo "  -s, --serial PORT      Serial port (auto-detect if not specified)"
    echo "  -d, --detach          Run in background (default for start)"
    echo "  -i, --interactive     Run interactively"
    echo "  --dev                 Use development image and configuration"
    echo "  --production         Use production image (default)"
    echo "  --no-serial          Skip serial port mounting"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start --dev                    # Start development container"
    echo "  $0 start --serial /dev/ttyUSB0    # Start with specific serial port"
    echo "  $0 logs --follow                  # Follow container logs"
    echo "  $0 shell                          # Open shell in running container"
}

# Function to detect serial ports
detect_serial_port() {
    log "🔍 Detecting Arduino serial ports..."
    
    local ports=()
    
    # Linux/Mac detection
    if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "darwin"* ]]; then
        # Look for common Arduino ports
        for port in /dev/ttyUSB* /dev/ttyACM* /dev/cu.usbmodem* /dev/cu.usbserial*; do
            if [ -e "$port" ]; then
                ports+=("$port")
            fi
        done
    fi
    
    # Windows detection (in WSL or Git Bash)
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
        warn "Windows detected - serial port mounting may require additional configuration"
        log "💡 On Windows, use Docker Desktop and ensure COM port is shared"
        # Default to COM3 for Windows
        ports+=("COM3")
    fi
    
    if [ ${#ports[@]} -eq 0 ]; then
        warn "No Arduino serial ports detected"
        log "📋 Available serial devices:"
        ls -la /dev/tty* 2>/dev/null | head -10 || log "No serial devices found"
        return 1
    else
        log "✅ Found serial ports: ${ports[*]}"
        echo "${ports[0]}"  # Return first port found
        return 0
    fi
}

# Function to check if container is running
is_container_running() {
    docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"
}

# Function to check if container exists (running or stopped)
container_exists() {
    docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"
}

# Function to start container
start_container() {
    local env_file="$1"
    local port="$2"
    local serial_port="$3"
    local mode="$4"
    local interactive="$5"
    local no_serial="$6"
    
    if is_container_running; then
        log "✅ Container is already running"
        return 0
    fi
    
    # Remove existing stopped container
    if container_exists; then
        log "🗑️  Removing existing stopped container..."
        docker rm "$CONTAINER_NAME" &>/dev/null || true
    fi
    
    # Determine image tag
    local image_tag=""
    if [ "$mode" = "dev" ]; then
        image_tag=":latest-dev"
    else
        image_tag=":latest"
    fi
    
    # Build docker run command
    local docker_cmd="docker run"
    local docker_args=()
    
    # Container name and image
    docker_args+=("--name" "$CONTAINER_NAME")
    
    # Port mapping
    docker_args+=("-p" "${port}:5000")
    
    # Environment file
    if [ -f "$env_file" ]; then
        docker_args+=("--env-file" "$env_file")
        log "📁 Using environment file: $env_file"
    else
        warn "Environment file not found: $env_file"
    fi
    
    # Serial port mounting
    if [ "$no_serial" != "true" ] && [ -n "$serial_port" ]; then
        if [ -e "$serial_port" ]; then
            docker_args+=("--device" "${serial_port}:${serial_port}")
            docker_args+=("--privileged")
            log "🔌 Mounting serial port: $serial_port"
        else
            warn "Serial port not found: $serial_port"
        fi
    fi
    
    # Volume mounts
    docker_args+=("-v" "$(pwd)/logs:/app/logs")
    docker_args+=("-v" "/etc/localtime:/etc/localtime:ro")
    
    # Interactive or detached mode
    if [ "$interactive" = "true" ]; then
        docker_args+=("-it")
        log "🖥️  Starting in interactive mode"
    else
        docker_args+=("-d")
        docker_args+=("--restart" "unless-stopped")
        log "🚀 Starting in background mode"
    fi
    
    # Health check
    docker_args+=("--health-cmd" "curl -f http://localhost:5000/health || exit 1")
    docker_args+=("--health-interval" "30s")
    docker_args+=("--health-timeout" "10s")
    docker_args+=("--health-retries" "3")
    
    # Add image
    docker_args+=("${IMAGE_NAME}${image_tag}")
    
    # Execute docker run
    log "🐳 Starting container with image: ${IMAGE_NAME}${image_tag}"
    $docker_cmd "${docker_args[@]}" || {
        error "Failed to start container"
        exit 1
    }
    
    if [ "$interactive" != "true" ]; then
        log "✅ Container started successfully"
        log "🌐 Access the application at: http://localhost:${port}"
        log "📊 Check status with: $0 status"
        log "📝 View logs with: $0 logs"
    fi
}

# Function to stop container
stop_container() {
    if ! is_container_running; then
        log "⏹️  Container is not running"
        return 0
    fi
    
    log "🛑 Stopping container..."
    docker stop "$CONTAINER_NAME" &>/dev/null || {
        error "Failed to stop container"
        exit 1
    }
    
    log "✅ Container stopped successfully"
}

# Function to show container logs
show_logs() {
    local follow="$1"
    
    if ! container_exists; then
        error "Container does not exist"
        exit 1
    fi
    
    local log_cmd="docker logs"
    if [ "$follow" = "true" ]; then
        log_cmd="$log_cmd -f"
    fi
    
    log "📝 Showing container logs..."
    $log_cmd "$CONTAINER_NAME"
}

# Function to open shell in container
open_shell() {
    if ! is_container_running; then
        error "Container is not running"
        exit 1
    fi
    
    log "🐚 Opening shell in container..."
    docker exec -it "$CONTAINER_NAME" /bin/bash
}

# Function to show container status
show_status() {
    log "📊 Container Status:"
    
    if is_container_running; then
        echo -e "${GREEN}Status: Running${NC}"
        docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        # Show health status
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
        echo -e "Health: ${GREEN}$health${NC}"
        
        # Show resource usage
        echo ""
        log "💻 Resource Usage:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" "$CONTAINER_NAME"
        
    elif container_exists; then
        echo -e "${YELLOW}Status: Stopped${NC}"
        docker ps -a --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}"
    else
        echo -e "${RED}Status: Not found${NC}"
    fi
}

# Function to cleanup containers and images
cleanup() {
    log "🧹 Cleaning up Docker resources..."
    
    # Stop and remove container if exists
    if container_exists; then
        if is_container_running; then
            docker stop "$CONTAINER_NAME" &>/dev/null || true
        fi
        docker rm "$CONTAINER_NAME" &>/dev/null || true
        log "🗑️  Removed container: $CONTAINER_NAME"
    fi
    
    # Remove dangling images
    docker image prune -f &>/dev/null || true
    
    # Remove unused volumes
    docker volume prune -f &>/dev/null || true
    
    log "✅ Cleanup completed"
}

# Main function
main() {
    local command=""
    local env_file=".env"
    local port="$DEFAULT_PORT"
    local serial_port=""
    local mode="production"
    local interactive="false"
    local no_serial="false"
    local follow_logs="false"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            start|stop|restart|logs|shell|status|cleanup)
                command="$1"
                shift
                ;;
            -e|--env-file)
                env_file="$2"
                shift 2
                ;;
            -p|--port)
                port="$2"
                shift 2
                ;;
            -s|--serial)
                serial_port="$2"
                shift 2
                ;;
            -d|--detach)
                interactive="false"
                shift
                ;;
            -i|--interactive)
                interactive="true"
                shift
                ;;
            --dev)
                mode="dev"
                shift
                ;;
            --production)
                mode="production"
                shift
                ;;
            --no-serial)
                no_serial="true"
                shift
                ;;
            --follow)
                follow_logs="true"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate command
    if [ -z "$command" ]; then
        error "No command specified"
        usage
        exit 1
    fi
    
    # Auto-detect serial port if not specified
    if [ -z "$serial_port" ] && [ "$no_serial" != "true" ]; then
        serial_port=$(detect_serial_port) || true
    fi
    
    log "🚀 Arduino Sensor Data Processor - Docker Management"
    log "📋 Configuration:"
    log "   Command: $command"
    log "   Mode: $mode"
    log "   Port: $port"
    log "   Serial Port: ${serial_port:-'(not mounted)'}"
    log "   Environment File: $env_file"
    
    # Execute command
    case $command in
        start)
            start_container "$env_file" "$port" "$serial_port" "$mode" "$interactive" "$no_serial"
            ;;
        stop)
            stop_container
            ;;
        restart)
            stop_container
            sleep 2
            start_container "$env_file" "$port" "$serial_port" "$mode" "$interactive" "$no_serial"
            ;;
        logs)
            show_logs "$follow_logs"
            ;;
        shell)
            open_shell
            ;;
        status)
            show_status
            ;;
        cleanup)
            cleanup
            ;;
        *)
            error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"