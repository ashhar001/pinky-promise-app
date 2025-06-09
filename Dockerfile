# Use official Node.js runtime as base image
FROM node:18-alpine AS base

# Build arguments
ARG APP_VERSION=unknown
ARG BUILD_DATE=unknown

# Set working directory in container
WORKDIR /app

# Copy package files for better caching
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S appuser -u 1001 -G nodejs

# Copy application code
COPY src/ ./src/

# Set environment variables
ENV NODE_ENV=production
ENV APP_VERSION=${APP_VERSION}
ENV BUILD_DATE=${BUILD_DATE}

# Change ownership to non-root user
RUN chown -R appuser:nodejs /app
USER appuser

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) }).on('error', () => process.exit(1))"

# Add labels
LABEL org.opencontainers.image.title="Pinky Promise App" \
      org.opencontainers.image.description="Sample Node.js app for GitOps" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/ashhar001/pinky-promise-app"

# Start application
CMD ["npm", "start"]

