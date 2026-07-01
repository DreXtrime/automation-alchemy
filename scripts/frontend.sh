#!/bin/bash
set -e

FRONTEND_IMAGE="ghcr.io/drextrime/infra-frontend:latest"
FRONTEND_PORT=8080
BACKEND_URL="http://192.168.56.20:5000"

# Pull latest image
docker pull "$FRONTEND_IMAGE"

# Stop and remove existing container if running
if docker ps -a --format '{{.Names}}' | grep -q "^infra-frontend$"; then
    docker stop infra-frontend
    docker rm infra-frontend
fi

# Run the infra-frontend container
docker run -d \
    --name infra-frontend \
    --restart unless-stopped \
    -p "$FRONTEND_PORT:$FRONTEND_PORT" \
    -e BACKEND_URL="$BACKEND_URL" \
    "$FRONTEND_IMAGE"