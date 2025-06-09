#!/bin/bash

# Pinky Promise App - Stop Script
# This script stops all running containers

echo "🛑 Stopping Pinky Promise App..."
echo "="*40

# Stop and remove containers
docker-compose -f deploy/docker-compose.yml down

echo "✅ All containers stopped"
echo "📊 To check status: docker-compose -f deploy/docker-compose.yml ps"
echo "🗑️  To remove volumes (delete data): docker-compose -f deploy/docker-compose.yml down --volumes"
echo "="*40

