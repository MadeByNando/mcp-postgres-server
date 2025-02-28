#!/bin/bash

# Script to run the MCP PostgreSQL Server in Docker

# Check if .env file exists
if [ ! -f .env ]; then
  echo "Error: .env file not found!"
  echo "Please create a .env file with your database credentials before running this script."
  exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  echo "Error: Docker is not installed or not in PATH!"
  exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
  echo "Error: Docker Compose is not installed or not in PATH!"
  exit 1
fi

# Create logs directory if it doesn't exist
mkdir -p logs

# Function to display usage
show_usage() {
  echo "Usage: ./docker-run.sh [OPTION]"
  echo "Options:"
  echo "  start       Build and start the container in detached mode"
  echo "  stop        Stop and remove the container"
  echo "  logs        View container logs"
  echo "  restart     Restart the container"
  echo "  cursor      Start a separate container for Cursor"
  echo "  build       Rebuild the Docker image"
  echo "  exec        Execute a command inside the container (e.g., './docker-run.sh exec \"node dist/index.js\"')"
  echo "  run         Run the server directly (shortcut for exec with node dist/index.js)"
  echo "  help        Display this help message"
}

# Process command line arguments
case "$1" in
  start)
    echo "Starting MCP PostgreSQL Server in Docker..."
    docker-compose up -d
    echo "Container started. Use './docker-run.sh logs' to view logs."
    ;;
  stop)
    echo "Stopping MCP PostgreSQL Server..."
    docker-compose down
    echo "Container stopped."
    ;;
  logs)
    echo "Showing logs (Ctrl+C to exit)..."
    docker-compose logs -f
    ;;
  restart)
    echo "Restarting MCP PostgreSQL Server..."
    docker-compose restart
    echo "Container restarted."
    ;;
  cursor)
    echo "Starting a separate container for Cursor..."
    # Load environment variables
    export $(grep -v '^#' .env | xargs)
    
    # Configuration
    DB_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@host.docker.internal:5432/${POSTGRES_DB}"
    CONTAINER_NAME="mcp-postgres-server-cursor"
    IMAGE_NAME="mcp-postgres-server-mcp-server"
    
    # Remove existing container if it exists
    if docker ps -a | grep -q $CONTAINER_NAME; then
      echo "Removing existing Cursor container..."
      docker rm -f $CONTAINER_NAME > /dev/null 2>&1
    fi
    
    # Run the container
    echo "Starting Cursor container..."
    docker run -i --rm --name $CONTAINER_NAME \
      -e DATABASE_URL="$DB_URL" \
      --add-host=host.docker.internal:host-gateway \
      $IMAGE_NAME
    ;;
  exec)
    if [ -z "$2" ]; then
      echo "Error: No command specified."
      echo "Usage: ./docker-run.sh exec \"COMMAND\""
      echo "Example: ./docker-run.sh exec \"node dist/index.js\""
      exit 1
    fi
    
    # Load environment variables
    export $(grep -v '^#' .env | xargs)
    
    # Build the database URL
    DB_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@host.docker.internal:5432/${POSTGRES_DB}"
    
    echo "Executing command in container: $2"
    docker exec -i \
      -e DATABASE_URL="$DB_URL" \
      mcp-postgres-server \
      sh -c "$2"
    ;;
  run)
    # Load environment variables
    export $(grep -v '^#' .env | xargs)
    
    # Build the database URL
    DB_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@host.docker.internal:5432/${POSTGRES_DB}"
    
    echo "Running MCP server directly in container..."
    docker exec -i \
      -e DATABASE_URL="$DB_URL" \
      mcp-postgres-server \
      node dist/index.js
    ;;
  build)
    echo "Rebuilding Docker image..."
    docker-compose build --no-cache
    echo "Image rebuilt."
    ;;
  help|*)
    show_usage
    ;;
esac 