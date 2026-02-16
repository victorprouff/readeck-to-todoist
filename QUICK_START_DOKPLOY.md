# 🚀 Guide Rapide - Déploiement Dokploy

## Étapes de déploiement

### 1. Préparation (sur votre machine locale)

```bash
# Clonez ou créez un dossier avec tous les fichiers
mkdir readeck-todoist-sync
cd readeck-todoist-sync

# Copiez tous ces fichiers dans le dossier :
# - Dockerfile
# - readeck-to-todoist.sh
# - crontab
# - entrypoint.sh
# - .dockerignore
```

### 2. Option A : Via Git (recommandé)

```bash
# Initialisez un repo Git
git init
git add .
git commit -m "Initial commit"

# Poussez vers votre plateforme Git (GitHub, GitLab, etc.)
git remote add origin https://github.com/votre-user/readeck-todoist-sync.git
git push -u origin main
```

**Dans Dokploy :**
1. Cliquez sur "Create Application"
2. Choisissez "Git Repository"
3. Connectez votre repository
4. Sélectionnez "Dockerfile" comme type de build
5. Passez à l'étape des variables d'environnement

### 3. Option B : Upload direct des fichiers

**Sur votre serveur Dokploy :**

```bash
# Connectez-vous en SSH
ssh votre-serveur

# Créez le dossier
mkdir -p /opt/dokploy/apps/readeck-todoist-sync
cd /opt/dokploy/apps/readeck-todoist-sync

# Uploadez tous les fichiers (via scp, rsync, ou manuellement)
```

**Dans Dokploy :**
1. Cliquez sur "Create Application"
2. Choisissez "Dockerfile"
3. Pointez vers `/opt/dokploy/apps/readeck-todoist-sync`
4. Passez à l'étape des variables d'environnement

### 4. Configuration des variables d'environnement

Dans Dokploy, section "Environment" :

```env
READECK_API_URL=https://readeck.example.com/api
READECK_API_TOKEN=votre_token_ici
TODOIST_API_TOKEN=votre_token_ici
TODOIST_PROJECT_ID=2234567890
TODOIST_SECTION_ID=123456789
```

### 5. Déploiement

1. Cliquez sur "Deploy"
2. Attendez la fin du build
3. Vérifiez les logs pour confirmer le démarrage

### 6. Vérification

**Vérifier que le conteneur tourne :**
```bash
docker ps | grep readeck-todoist
```

**Voir les logs de démarrage :**
Dans Dokploy : Onglet "Logs"

**Tester manuellement :**
```bash
# Récupérez le nom du conteneur
docker ps | grep readeck-todoist

# Exécutez le script
docker exec -it <nom_conteneur> /app/readeck-to-todoist.sh
```

### 7. Consulter les logs du cron

```bash
# Logs du dernier run
docker exec -it <nom_conteneur> tail -100 /var/log/readeck-sync/sync.log

# Suivre les logs en temps réel
docker exec -it <nom_conteneur> tail -f /var/log/readeck-sync/sync.log
```

## 📅 Planification actuelle

**Tous les mardis à 19h** (fuseau Europe/Paris)

## 🔧 Modifier la planification

Pour changer l'horaire, éditez le fichier `crontab` :

```cron
# Exemples :
0 19 * * 2     # Mardis à 19h (actuel)
0 20 * * *     # Tous les jours à 20h
0 9 * * 1      # Lundis à 9h
0 19 * * 2,5   # Mardis et vendredis à 19h
*/30 * * * *   # Toutes les 30 minutes
```

Puis redéployez l'application dans Dokploy.

## ❓ Problèmes courants

### Le conteneur ne démarre pas
- Vérifiez que toutes les variables d'env sont définies
- Consultez les logs dans Dokploy

### Le script ne s'exécute pas
```bash
# Vérifier que cron tourne
docker exec -it <nom_conteneur> ps aux | grep cron

# Vérifier la planification
docker exec -it <nom_conteneur> cat /etc/crontabs/root

# Tester manuellement
docker exec -it <nom_conteneur> /app/readeck-to-todoist.sh
```

### Erreurs d'authentification API
- Vérifiez vos tokens dans les variables d'environnement
- Testez avec `curl` pour vérifier la validité

## 🎯 Prochaines étapes

Une fois déployé, le système est autonome ! 

Chaque mardi à 19h :
1. ✅ Récupération des articles "en vrac" depuis Readeck
2. ✅ Ajout dans Todoist
3. ✅ Archivage sur Readeck
4. ✅ Rapport dans les logs
