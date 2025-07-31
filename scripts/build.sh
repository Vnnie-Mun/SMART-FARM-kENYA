#!/bin/bash

# Build script for Arduino Sensor Data Processor Docker images
# Supports both production and development builds with proper tagging

set -e

# Configuration
IMAGE_NAME="arduino-sensor-processor"
VERSION=$(grep "version" package.json 2>/dev/null | cut -d'"' -f4 || echo "2.0.0")
REGISTRY="${DOCKER_REGISTRY:-}"

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
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --type TYPE      Build type: production|dev|both (default: production)"
    echo "  -p, --platform ARCH  Target platform: linux/amd64|linux/arm64|both (default: linux/amd64)"
    echo "  -r, --registry URL   Docker registry URL (optional)"
    echo "  -v, --version VER    Version tag (default: $VERSION)"
    echo "  --no-cache          Build without cache"
    echo "  --push              Push images to registry after build"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --type production --platform linux/amd64"
    echo "  $0 --type dev --no-cache"
    echo "  $0 --type both --platform both --push"
}

# Function to check prerequisites
check_prerequisites() {
    log "🔍 Checking prerequisites..."
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running"
        exit 1
    fi
    
    # Check if buildx is available for multi-platform builds
    if ! docker buildx version &> /dev/null; then
        warn "Docker buildx not available - multi-platform builds not supported"
    fi
    
    log "✅ Prerequisites check passed"
}

# Function to build image
build_image() {
    local dockerfile=$1
    local tag_suffix=$2
    local platform=$3
    local no_cache_flag=$4
    
    local full_tag="${IMAGE_NAME}:${VERSION}${tag_suffix}"
    if [ -n "$REGISTRY" ]; then
        full_tag="${REGISTRY}/${full_tag}"
    fi
    
    log "🔨 Building ${full_tag} for platform ${platform}..."
    
    local build_cmd="docker build"
    local build_args=""
    
    # Add platform support if specified
    if [ "$platform" != "default" ]; then
        if docker buildx version &> /dev/null; then
            build_cmd="docker buildx build"
            build_args="--platform ${platform}"
        else
            warn "Multi-platform build requested but buildx not available"
        fi
    fi
    
    # Add no-cache flag if specified
    if [ "$no_cache_flag" = "true" ]; then
        build_args="$build_args --no-cache"
    fi
    
    # Build the image
    $build_cmd \
        $build_args \
        -f "$dockerfile" \
        -t "$full_tag" \
        -t "${IMAGE_NAME}:latest${tag_suffix}" \
        --build-arg VERSION="$VERSION" \
        --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        --build-arg VCS_REF="$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')" \
        . || {
        error "Failed to build $full_tag"
        exit 1
    }
    
    log "✅ Successfully built $full_tag"
    
    # Show image size
    local image_size=$(docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep "$full_tag" | awk '{print $2}')
    log "📊 Image size: $image_size"
}

# Function to push image
push_image() {
    local tag_suffix=$1
    
    if [ -z "$REGISTRY" ]; then
        warn "No registry specified, skipping push"
        return
    fi
    
    local full_tag="${REGISTRY}/${IMAGE_NAME}:${VERSION}${tag_suffix}"
    
    log "📤 Pushing $full_tag..."
    
    docker push "$full_tag" || {
        error "Failed to push $full_tag"
        exit 1
    }
    
    log "✅ Successfully pushed $full_tag"
}

# Function to create multi-platform builder
setup_buildx() {
    local platform=$1
    
    if [ "$platform" = "both" ] && docker buildx version &> /dev/null; then
        log "🔧 Setting up multi-platform builder..."
        
        docker buildx create --name arduino-builder --use 2>/dev/null || true
        docker buildx inspect --bootstrap
        
        log "✅ Multi-platform builder ready"
    fi
}

# Function to clean up build artifacts
cleanup() {
    log "🧹 Cleaning up build artifacts..."
    
    # Remove dangling images
    docker image prune -f &> /dev/null || true
    
    # Remove buildx builder if created
    if docker buildx ls | grep -q arduino-builder; then
        docker buildx rm arduino-builder &> /dev/null || true
    fi
    
    log "✅ Cleanup completed"
}

# Main build function
main() {
    local build_type="production"
    local platform="linux/amd64"
    local no_cache="false"
    local push_images="false"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--type)
                build_type="$2"
                shift 2
                ;;
            -p|--platform)
                platform="$2"
                shift 2
                ;;
            -r|--registry)
                REGISTRY="$2"
                shift 2
                ;;
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            --no-cache)
                no_cache="true"
                shift
                ;;
            --push)
                push_images="true"
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
    
    # Validate build type
    if [[ ! "$build_type" =~ ^(production|dev|both)$ ]]; then
        error "Invalid build type: $build_type"
        usage
        exit 1
    fi
    
    # Validate platform
    if [[ ! "$platform" =~ ^(linux/amd64|linux/arm64|both|default)$ ]]; then
        error "Invalid platform: $platform"
        usage
        exit 1
    fi
    
    log "🚀 Starting Docker build process"
    log "📋 Configuration:"
    log "   Build Type: $build_type"
    log "   Platform: $platform"
    log "   Version: $VERSION"
    log "   Registry: ${REGISTRY:-'(none)'}"
    log "   No Cache: $no_cache"
    log "   Push: $push_images"
    
    # Check prerequisites
    check_prerequisites
    
    # Setup buildx for multi-platform builds
    if [ "$platform" = "both" ]; then
        setup_buildx "$platform"
        platform="linux/amd64,linux/arm64"
    fi
    
    # Build production image
    if [[ "$build_type" =~ ^(production|both)$ ]]; then
        build_image "Dockerfile" "" "$platform" "$no_cache"
        
        if [ "$push_images" = "true" ]; then
            push_image ""
        fi
    fi
    
    # Build development image
    if [[ "$build_type" =~ ^(dev|both)$ ]]; then
        build_image "Dockerfile.dev" "-dev" "$platform" "$no_cache"
        
        if [ "$push_images" = "true" ]; then
            push_image "-dev"
        fi
    fi
    
    # Show final summary
    log "🎉 Build process completed successfully!"
    log "📊 Built images:"
    docker images | grep "$IMAGE_NAME" | head -10
    
    # Cleanup
    cleanup
}

# Trap signals for cleanup
trap cleanup EXIT

# Run main function
main "$@"