#!/bin/sh
set -e

echo "Starting MCP PostgreSQL Server..."

# Function to handle termination signals
cleanup() {
  echo "Stopping MCP PostgreSQL server..."
  if [ -n "$SERVER_PID" ]; then
    kill -TERM $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
  fi
  echo "Server stopped gracefully"
  exit 0
}

# Set up signal trapping
trap cleanup SIGTERM SIGINT

# Start the MCP server
if [ -n "$DATABASE_URL" ]; then
  echo "Using DATABASE_URL from environment: $(echo $DATABASE_URL | sed 's/:[^:]*@/:***@/')"
  node dist/index.js "$DATABASE_URL" &
else
  echo "No DATABASE_URL provided, using default connection"
  node dist/index.js "postgresql://postgres:postgres@host.docker.internal:5432/Employees" &
fi

SERVER_PID=$!

# Keep the container running
echo "MCP PostgreSQL server running with PID $SERVER_PID"
echo "Container will stay alive. Use Ctrl+C to stop."

# Wait indefinitely and restart if needed
while true; do
  # Check if server is still running
  if ! kill -0 $SERVER_PID 2>/dev/null; then
    echo "MCP server process has stopped. Restarting..."
    
    if [ -n "$DATABASE_URL" ]; then
      node dist/index.js "$DATABASE_URL" &
    else
      node dist/index.js "postgresql://postgres:postgres@host.docker.internal:5432/Employees" &
    fi
    
    SERVER_PID=$!
    echo "MCP server restarted with PID $SERVER_PID"
  fi
  sleep 5
done 