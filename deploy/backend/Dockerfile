# Backend Dockerfile
FROM node:16-alpine
WORKDIR /app

# Set environment variables
ENV NODE_ENV=production
ENV PORT=5001

# Install dependencies
COPY package*.json ./
RUN npm install --production

# Copy application files
COPY . .

# Expose port
EXPOSE ${PORT}

# Start the application
CMD ["node", "server.js"]
