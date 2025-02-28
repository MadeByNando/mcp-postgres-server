#!/bin/bash

# Script de connexion MCP pour Cursor
# Ce script crée un nouveau conteneur pour Cursor qui se connecte directement via StdioServerTransport

# Charger les variables depuis le fichier .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "⚠️ ATTENTION: Fichier .env non trouvé."
  exit 1
fi

# Configuration
DB_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@host.docker.internal:5432/${POSTGRES_DB}"
CONTAINER_NAME="mcp-postgres-server-cursor"
IMAGE_NAME="mcp-postgres-server-mcp-server"

# Vérifier si un conteneur avec le même nom existe déjà
if docker ps -a | grep -q $CONTAINER_NAME; then
  echo "Un conteneur nommé $CONTAINER_NAME existe déjà. Suppression..."
  docker rm -f $CONTAINER_NAME > /dev/null 2>&1
fi

echo "🚀 Création d'un nouveau conteneur MCP pour Cursor..."

# Exécuter le conteneur avec un nom différent
docker run -i --rm --name $CONTAINER_NAME \
  -e DATABASE_URL="$DB_URL" \
  --add-host=host.docker.internal:host-gateway \
  $IMAGE_NAME

# Note: Ce script doit être exécuté dans une fenêtre de terminal séparée
# Cursor doit être configuré pour utiliser la commande:
# ./cursor-connect.sh 