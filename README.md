# Synchronisation Readeck / YouTube → Todoist

Script bash qui alimente un projet Todoist avec la veille "en vrac" :

- **Readeck** : les articles non archivés avec le label "en vrac" sont ajoutés à Todoist puis archivés.
- **YouTube** : les vidéos d'une playlist sont ajoutées à Todoist puis retirées de la playlist.

Chaque source est activée uniquement si ses variables d'environnement sont définies.


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
| `YOUTUBE_PLAYLIST_ID` | ID de la playlist YouTube à vider (ex: `PLxxxxxxxx`) |
| `YOUTUBE_CLIENT_ID` | Client ID OAuth Google |
| `YOUTUBE_CLIENT_SECRET` | Client secret OAuth Google |
| `YOUTUBE_REFRESH_TOKEN` | Refresh token OAuth (voir ci-dessous) |
| `YOUTUBE_TODOIST_SECTION_ID` | Optionnel : section Todoist des vidéos (défaut : `TODOIST_SECTION_ID`) |

Les variables `READECK_*` et `YOUTUBE_*` sont optionnelles, mais au moins une des deux sources doit être configurée entièrement.

### Configuration YouTube

Retirer une vidéo d'une playlist nécessite OAuth (une simple clé API ne suffit pas).

1. Dans [Google Cloud Console](https://console.cloud.google.com/) :
   - activer l'API **YouTube Data API v3** ;
   - créer un **ID client OAuth** de type **Application de bureau** ;
   - dans l'écran de consentement OAuth, passer l'application en **Production** (sinon le refresh token expire au bout de 7 jours). Pas besoin de validation Google pour un usage personnel.
2. En local, lancer une seule fois :
   ```bash
   YOUTUBE_CLIENT_ID=... YOUTUBE_CLIENT_SECRET=... ./get-youtube-refresh-token.sh
   ```
   puis reporter le `YOUTUBE_REFRESH_TOKEN` affiché dans Dokploy.

### Crons Dokploy

Deux crons à configurer, tous les deux avec le container `readeck-todoist-sync` :

| Commande | Rôle |
|---|---|
| `/app/readeck-to-todoist.sh` | Synchronisation principale |
| `/app/debug-readeck.sh` | Vérification de la connexion Readeck sans synchroniser |

## Tester sans rien modifier

`DRY_RUN=1` effectue uniquement les lectures (récupération des articles et des vidéos) et affiche ce qui serait fait, sans ajouter de tâche dans Todoist, archiver d'article ni retirer de vidéo.

Pour ne tester que YouTube, il suffit de ne pas définir les variables `READECK_*` :

```bash
DRY_RUN=1 READECK_API_URL= READECK_API_TOKEN= ./readeck-to-todoist.sh
```

Dans le conteneur : `docker exec -e DRY_RUN=1 -e READECK_API_URL= -e READECK_API_TOKEN= readeck-todoist-sync /app/readeck-to-todoist.sh`

## Fonctionnement du script principal

1. Récupère tous les articles Readeck avec :
   - `is_archived=false` (non archivés)
   - `labels="en vrac"` (avec le label "en vrac")

2. Pour chaque article trouvé :
   - Extrait le titre et l'URL
   - Crée une tâche Todoist au format markdown `[Titre](URL)`
   - Ajoute la tâche dans le projet/section configurés

3. Pour chaque vidéo de la playlist YouTube :
   - Crée une tâche Todoist `[Titre](https://www.youtube.com/watch?v=ID)`
   - Retire la vidéo de la playlist si l'ajout a réussi
   - Ignore les vidéos supprimées ou privées (elles restent dans la playlist)

4. Logs colorés :
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
- `get-youtube-refresh-token.sh` : obtention du refresh token YouTube (à lancer en local)
- `entrypoint.sh` : point d'entrée du conteneur
- `docker-compose.yml` : configuration du service

## Licence

Script personnel - Libre d'utilisation et de modification
