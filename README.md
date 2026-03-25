# Synchronisation Readeck → Todoist

Script bash pour synchroniser automatiquement les articles non archivés avec le label "en vrac" de Readeck vers une section spécifique d'un projet Todoist.

## Prérequis

- `curl` (généralement préinstallé)
- `jq` pour le parsing JSON

## Déploiement avec Dokploy

### Architecture

Le conteneur tourne en permanence (`sleep infinity` + `restart: unless-stopped`). Dokploy utilise `docker exec` pour déclencher les scripts selon le planning configuré.

### Variables d'environnement

Configurer dans Dokploy :

| Variable | Description |
|---|---|
| `READECK_API_URL` | URL de base de l'instance Readeck (ex: `https://readeck.example.com/api`) |
| `READECK_API_TOKEN` | Token Bearer pour l'API Readeck |
| `TODOIST_API_TOKEN` | Token pour l'API Todoist |
| `TODOIST_PROJECT_ID` | ID du projet Todoist (ex: `6X6Hrfezff5rthWCXH`) |
| `TODOIST_SECTION_ID` | ID de la section Todoist (ex: `HesrhXfQ9trhXV9`) |

### Crons Dokploy

Deux crons à configurer, tous les deux avec le container `readeck-todoist-sync` :

| Commande | Rôle |
|---|---|
| `/app/readeck-to-todoist.sh` | Synchronisation principale |
| `/app/debug-readeck.sh` | Vérification de la connexion Readeck sans synchroniser |

## Fonctionnement du script principal

1. Récupère tous les articles Readeck avec :
   - `is_archived=false` (non archivés)
   - `labels="en vrac"` (avec le label "en vrac")

2. Pour chaque article trouvé :
   - Extrait le titre et l'URL
   - Crée une tâche Todoist au format markdown `[Titre](URL)`
   - Ajoute la tâche dans le projet/section configurés

3. Logs colorés :
   - 🟢 INFO : opérations normales
   - 🟡 WARN : avertissements
   - 🔴 ERROR : erreurs

## Dépannage

### Erreur "jq: parse error: Invalid numeric literal"

Causes possibles :
1. L'API Readeck retourne une réponse vide (aucun article trouvé)
2. Le label est mal encodé dans l'URL
3. Le token d'authentification est invalide

**Note :** L'API Readeck nécessite que les labels avec espaces soient encodés avec des guillemets : `labels=%22en+vrac%22`.

### Erreur HTTP 401 (Unauthorized)

Vérifiez que les tokens sont corrects et valides.

### Erreur HTTP 404

Vérifiez que les IDs de projet et de section Todoist sont corrects.

### Aucun article trouvé

Vérifiez que :
- Le label est bien "en vrac" (sensible à la casse)
- Il existe des articles non archivés avec ce label dans Readeck

## Structure du code

- `readeck-to-todoist.sh` : script principal de synchronisation
- `debug-readeck.sh` : script de vérification de l'API Readeck
- `entrypoint.sh` : point d'entrée du conteneur
- `docker-compose.yml` : configuration du service

## Licence

Script personnel - Libre d'utilisation et de modification
