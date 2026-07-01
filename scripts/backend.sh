#!/bin/bash
set -e

BACKEND_IMAGE="ghcr.io/drextrime/infra-backend:latest"
BACKEND_PORT=5000

# Pull latest image
docker pull "$BACKEND_IMAGE"

# Stop and remove existing container if running
if docker ps -a --format '{{.Names}}' | grep -q "^infra-backend$"; then
    docker stop infra-backend
    docker rm infra-backend
fi

# Run the backend container
docker run -d \
    --name infra-backend \
    --restart unless-stopped \
    -p "$BACKEND_PORT:$BACKEND_PORT" \
    "$BACKEND_IMAGE"