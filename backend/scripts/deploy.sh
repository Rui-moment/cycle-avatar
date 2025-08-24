#!/bin/bash

# CycleAvatar Production Deployment Script

set -e

echo "🚀 Starting CycleAvatar production deployment..."

# Configuration
DOCKER_COMPOSE_FILE="docker-compose.prod.yml"
BACKUP_BEFORE_DEPLOY=true
HEALTH_CHECK_TIMEOUT=60

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi
    
    if [ ! -f ".env.production" ]; then
        log_error ".env.production file not found"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Create backup before deployment
create_backup() {
    if [ "$BACKUP_BEFORE_DEPLOY" = true ]; then
        log_info "Creating backup before deployment..."
        docker-compose -f $DOCKER_COMPOSE_FILE exec -T db pg_dump -U cycleavatar_user cycleavatar_prod > "backup_pre_deploy_$(date +%Y%m%d_%H%M%S).sql"
        log_info "Backup created successfully"
    fi
}

# Build and deploy
deploy() {
    log_info "Building and deploying application..."
    
    # Pull latest images
    docker-compose -f $DOCKER_COMPOSE_FILE pull
    
    # Build application image
    docker-compose -f $DOCKER_COMPOSE_FILE build --no-cache app
    
    # Stop existing containers
    log_info "Stopping existing containers..."
    docker-compose -f $DOCKER_COMPOSE_FILE down
    
    # Start new containers
    log_info "Starting new containers..."
    docker-compose -f $DOCKER_COMPOSE_FILE up -d
    
    log_info "Deployment completed"
}

# Health check
health_check() {
    log_info "Performing health check..."
    
    local timeout=$HEALTH_CHECK_TIMEOUT
    local count=0
    
    while [ $count -lt $timeout ]; do
        if curl -f http://localhost:8000/health &> /dev/null; then
            log_info "Health check passed"
            return 0
        fi
        
        sleep 1
        count=$((count + 1))
        
        if [ $((count % 10)) -eq 0 ]; then
            log_warn "Still waiting for application to be healthy... ($count/$timeout)"
        fi
    done
    
    log_error "Health check failed after $timeout seconds"
    return 1
}

# Rollback function
rollback() {
    log_warn "Rolling back deployment..."
    
    # Stop current containers
    docker-compose -f $DOCKER_COMPOSE_FILE down
    
    # Restore from backup if available
    local latest_backup=$(ls -t backup_pre_deploy_*.sql 2>/dev/null | head -n1)
    if [ ! -z "$latest_backup" ]; then
        log_info "Restoring from backup: $latest_backup"
        docker-compose -f $DOCKER_COMPOSE_FILE up -d db
        sleep 10
        docker-compose -f $DOCKER_COMPOSE_FILE exec -T db psql -U cycleavatar_user -d cycleavatar_prod < "$latest_backup"
    fi
    
    # Start previous version (this would need to be implemented based on your versioning strategy)
    log_warn "Manual intervention required to restore previous version"
}

# Main deployment process
main() {
    log_info "CycleAvatar Production Deployment Started"
    
    check_prerequisites
    create_backup
    deploy
    
    if health_check; then
        log_info "✅ Deployment successful!"
        
        # Clean up old images
        docker image prune -f
        
        # Send success notification
        if [ ! -z "$SLACK_WEBHOOK_URL" ]; then
            curl -X POST -H 'Content-type: application/json' \
                --data '{"text":"✅ CycleAvatar production deployment successful!"}' \
                $SLACK_WEBHOOK_URL
        fi
    else
        log_error "❌ Deployment failed!"
        rollback
        
        # Send failure notification
        if [ ! -z "$SLACK_WEBHOOK_URL" ]; then
            curl -X POST -H 'Content-type: application/json' \
                --data '{"text":"❌ CycleAvatar production deployment failed and rolled back!"}' \
                $SLACK_WEBHOOK_URL
        fi
        
        exit 1
    fi
}

# Handle script interruption
trap 'log_error "Deployment interrupted"; rollback; exit 1' INT TERM

# Run main function
main "$@"