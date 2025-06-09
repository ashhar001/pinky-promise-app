#!/bin/bash
# Helper script for local deployment testing

set -e

# Navigate to project root
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
PROJECT_ROOT="$(pwd)"

# Check if Docker is running
if ! docker info &>/dev/null; then
  echo "Error: Docker is not running. Please start Docker and try again."
  exit 1
fi

# Build and run the application with docker-compose
echo "Building and starting containers..."
docker-compose -f "$PROJECT_ROOT/deploy/docker-compose.yml" up --build -d

# Display container status
echo "Container status:"
docker-compose -f "$PROJECT_ROOT/deploy/docker-compose.yml" ps

# Display access URLs
echo ""
echo "Your application is now running!"
echo "Frontend: http://localhost"
echo "Backend API: http://localhost:5001"
echo ""
echo "To view logs:"
echo "  docker-compose -f \"$PROJECT_ROOT/deploy/docker-compose.yml\" logs -f"
echo ""
echo "To stop the application:"
echo "  docker-compose -f \"$PROJECT_ROOT/deploy/docker-compose.yml\" down"
