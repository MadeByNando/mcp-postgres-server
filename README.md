# MCP Postgres Server

Ce serveur implémente le protocole MCP (Model Context Protocol) pour Cursor, permettant d'utiliser une base de données PostgreSQL comme stockage pour les contextes de modèle.

## Prérequis

- Docker
- Docker Compose

## Installation et démarrage

1. Clonez ce dépôt
2. Exécutez le script de connexion pour Cursor:

```bash
./cursor-connect.sh
```

Le script effectuera automatiquement les actions suivantes:

- Suppression de tout conteneur MCP existant avec le même nom
- Création d'un nouveau conteneur dédié à Cursor
- Connexion à la base de données PostgreSQL

## Configuration dans Cursor

1. Ouvrez Cursor
2. Allez dans Paramètres > MCP
3. Ajoutez une nouvelle connexion avec les paramètres suivants:
   - Nom: MCP Postgres Server
   - Type: command
   - Commande: `./cursor-connect.sh`

## Résolution des problèmes

Si le serveur ne démarre pas correctement:

1. Vérifiez les logs du conteneur:

   ```bash
   docker logs mcp-postgres-server-cursor
   ```

2. Pour redémarrer le serveur, il suffit de relancer le script:

   ```bash
   ./cursor-connect.sh
   ```

## Fonctionnalités du serveur MCP

Le serveur MCP PostgreSQL expose les outils suivants pour Cursor:

1. `postgres_query` - Exécuter une requête SQL en lecture seule
2. `postgres_list_tables` - Lister toutes les tables de la base de données
3. `postgres_describe_table` - Obtenir le schéma d'une table spécifique

Ces outils permettent à Cursor d'explorer et d'interroger la base de données de manière sécurisée.
