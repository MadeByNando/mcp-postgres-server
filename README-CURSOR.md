# Connexion du serveur MCP à Cursor

Ce document explique comment connecter le serveur MCP PostgreSQL à Cursor.

## Approche

Le serveur MCP PostgreSQL est conçu pour être utilisé exclusivement avec Cursor. Le script `cursor-connect.sh` crée un conteneur Docker dédié qui se connecte directement à Cursor via le protocole MCP.

## Comment utiliser

1. Assurez-vous que le script `cursor-connect.sh` est exécutable :

   ```bash
   chmod +x cursor-connect.sh
   ```

2. Ouvrez Cursor et configurez une nouvelle connexion MCP :
   - Ouvrez Cursor
   - Allez dans Paramètres (icône d'engrenage)
   - Naviguez vers la section "MCP"
   - Cliquez sur "Ajouter une connexion"
   - Configurez la connexion avec ces paramètres :
     - Nom : MCP Postgres Server
     - Type : command
     - Commande : `./cursor-connect.sh`

3. Lorsque vous utilisez cette connexion dans Cursor, le script :
   - Démarre un nouveau conteneur nommé `mcp-postgres-server-cursor`
   - Exécute le serveur MCP avec la chaîne de connexion à la base de données correcte
   - Se connecte à Cursor en utilisant StdioServerTransport

## Remarques

- Le script doit être exécuté dans une fenêtre de terminal séparée
- Le conteneur est automatiquement supprimé lorsque le script est arrêté
- Ce script est la méthode recommandée et unique pour connecter le serveur MCP à Cursor