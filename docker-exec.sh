#!/bin/bash

# Simple wrapper for docker exec with proper environment variables
# Usage: ./docker-exec.sh COMMAND [ARGS...]

# Check if .env file exists
if [ ! -f .env ]; then
  echo "Error: .env file not found!"
  echo "Please create a .env file with your database credentials before running this script."
  exit 1
fi

# Check if a command was provided
if [ $# -eq 0 ]; then
  echo "Error: No command specified."
  echo "Usage: ./docker-exec.sh COMMAND [ARGS...]"
  echo "Example: ./docker-exec.sh node dist/index.js"
  exit 1
fi

# Load environment variables
export $(grep -v '^#' .env | xargs)

# Build the database URL
DB_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@host.docker.internal:5432/${POSTGRES_DB}"

# Execute the command
docker exec -i \
  -e DATABASE_URL="$DB_URL" \
  mcp-postgres-server \
  "$@" 