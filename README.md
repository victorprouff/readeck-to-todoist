# Synchronisation Readeck → Todoist

Script bash pour synchroniser automatiquement les articles non archivés avec le label "en vrac" de Readeck vers une section spécifique d'un projet Todoist.

## Prérequis

- `curl` (généralement préinstallé)
- `jq` pour le parsing JSON

Installation de jq sur Debian/Ubuntu :
```bash
sudo apt-get update
sudo apt-get install -y jq
```

## Installation

1. Téléchargez le script sur votre serveur :
```bash
wget https://votre-serveur.com/readeck-to-todoist.sh
# OU
curl -O https://votre-serveur.com/readeck-to-todoist.sh
```

2. Rendez le script exécutable :
```bash
chmod +x readeck-to-todoist.sh
```

## Configuration

### Variables d'environnement

Le script nécessite deux variables d'environnement :

1. **READECK_API_TOKEN** : Token d'authentification Bearer pour l'API Readeck
2. **TODOIST_API_TOKEN** : Token d'authentification pour l'API Todoist

### Obtenir le token Readeck

1. Connectez-vous à votre instance Readeck : https://readeck.victorprouff.fr
2. Allez dans les paramètres de votre compte
3. Générez un token API
4. Copiez le token

### Obtenir le token Todoist

1. Allez sur https://todoist.com/app/settings/integrations
2. Sous "API token", copiez votre token
3. Ou générez un nouveau token si nécessaire

### Définir les variables d'environnement

#### Option 1 : Variables système (recommandé pour cron)

Ajoutez les variables dans `/etc/environment` :
```bash
sudo nano /etc/environment
```

Ajoutez ces lignes :
```
READECK_API_TOKEN="votre_token_readeck_ici"
TODOIST_API_TOKEN="votre_token_todoist_ici"
```

Rechargez l'environnement :
```bash
source /etc/environment
```

#### Option 2 : Profile utilisateur

Ajoutez dans `~/.bashrc` ou `~/.profile` :
```bash
export READECK_API_TOKEN="votre_token_readeck_ici"
export TODOIST_API_TOKEN="votre_token_todoist_ici"
```

Rechargez :
```bash
source ~/.bashrc
```

## Utilisation

### Exécution manuelle

```bash
./readeck-to-todoist.sh
```

### Configuration du cron

Pour exécuter le script automatiquement, utilisez cron.

1. Éditez le crontab :
```bash
crontab -e
```

2. Ajoutez une ligne selon la fréquence souhaitée :

```bash
# Toutes les heures
0 * * * * /chemin/vers/readeck-to-todoist.sh >> /var/log/readeck-todoist.log 2>&1

# Tous les jours à 9h00
0 9 * * * /chemin/vers/readeck-to-todoist.sh >> /var/log/readeck-todoist.log 2>&1

# Toutes les 6 heures
0 */6 * * * /chemin/vers/readeck-to-todoist.sh >> /var/log/readeck-todoist.log 2>&1

# Toutes les 30 minutes
*/30 * * * * /chemin/vers/readeck-to-todoist.sh >> /var/log/readeck-todoist.log 2>&1
```

3. **Important pour cron** : Les variables d'environnement doivent être définies dans le crontab si elles ne sont pas dans `/etc/environment` :

```bash
READECK_API_TOKEN=votre_token_readeck
TODOIST_API_TOKEN=votre_token_todoist

0 * * * * /chemin/vers/readeck-to-todoist.sh >> /var/log/readeck-todoist.log 2>&1
```

### Vérifier les logs

```bash
tail -f /var/log/readeck-todoist.log
```

## Fonctionnement du script

1. Le script récupère tous les articles Readeck avec :
   - `is_archived=false` (non archivés)
   - `labels="en vrac"` (avec le label "en vrac")

2. Pour chaque article trouvé :
   - Extrait le titre et l'URL
   - Crée une tâche Todoist avec le format markdown `[Titre](URL)`
   - Ajoute la tâche dans le projet ID `2332182173`, section ID `179438112`

3. Le script affiche des logs colorés :
   - 🟢 INFO : opérations normales
   - 🟡 WARN : avertissements
   - 🔴 ERROR : erreurs

## Dépannage

### Le script ne trouve pas les tokens

Vérifiez que les variables sont bien définies :
```bash
echo $READECK_API_TOKEN
echo $TODOIST_API_TOKEN
```

Si vides, redéfinissez-les selon la section Configuration.

### Erreur "jq: command not found"

Installez jq :
```bash
sudo apt-get install -y jq
```

### Erreur HTTP 401 (Unauthorized)

Vérifiez que vos tokens sont corrects et valides.

### Erreur HTTP 404

Vérifiez que les IDs de projet et de section Todoist sont corrects.

### Aucun article trouvé

Vérifiez que :
- Le label est bien "en vrac" (sensible à la casse)
- Il existe des articles non archivés avec ce label dans Readeck

## Évolutions futures

- ✅ Synchronisation Readeck → Todoist
- 🔄 Archivage automatique des articles traités dans Readeck (à venir)
- 📊 Rapport détaillé par email (à venir)

## Structure du code

Le script est organisé en fonctions :
- `check_env_vars()` : Vérifie les variables d'environnement
- `check_dependencies()` : Vérifie les dépendances système
- `fetch_readeck_articles()` : Récupère les articles depuis Readeck
- `add_todoist_task()` : Ajoute une tâche dans Todoist
- `main()` : Fonction principale qui orchestre le tout

## Licence

Script personnel - Libre d'utilisation et de modification
