#!/bin/bash

# Pinky Promise App - Quick Start Script
# This script helps you get the application running quickly

set -e  # Exit on any error

echo "🚀 Starting Pinky Promise App..."
echo "="*50

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running. Please start Docker and try again."
    exit 1
fi

echo "✅ Docker is running"

# Check if .env file exists
if [ ! -f "deploy/.env" ]; then
    echo "📝 Creating environment file..."
    cp deploy/.env.example deploy/.env
    echo "✅ Environment file created at deploy/.env"
    echo "⚠️  Please edit deploy/.env with your configuration before production use!"
else
    echo "✅ Environment file exists"
fi

# Stop any existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f deploy/docker-compose.yml down > /dev/null 2>&1 || true

# Build and start services
echo "🏗️  Building and starting services..."
docker-compose -f deploy/docker-compose.yml up --build -d

# Wait for database to be ready
echo "⏳ Waiting for database to be ready..."
sleep 10

# Initialize database schema
echo "🗃️  Initializing database schema..."
docker exec -i pinky-promise-db psql -U postgres -d pinky_promise < backend/schema.sql

echo "="*50
echo "🎉 Application is now running!"
echo ""
echo "📱 Frontend: http://localhost"
echo "🔧 Backend API: http://localhost:5001"
echo "🗄️  Database: localhost:5432"
echo ""
echo "📊 Check status: docker-compose -f deploy/docker-compose.yml ps"
echo "📋 View logs: docker-compose -f deploy/docker-compose.yml logs -f"
echo "🛑 Stop app: docker-compose -f deploy/docker-compose.yml down"
echo "="*50

