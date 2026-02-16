# Readeck to Todoist Sync - Déploiement Dokploy

Ce projet synchronise automatiquement les articles Readeck vers Todoist et les archive.

## 📋 Prérequis

- Instance Dokploy fonctionnelle
- Compte Readeck avec API activée
- Compte Todoist avec accès API
- Git repository (ou déploiement manuel)

## 🚀 Déploiement sur Dokploy

### Option 1 : Déploiement via Git

1. **Créer un repository Git** avec tous les fichiers :
   - `Dockerfile`
   - `readeck-to-todoist.sh`
   - `crontab`
   - `entrypoint.sh`
   - `.dockerignore`

2. **Dans Dokploy** :
   - Créer une nouvelle application
   - Choisir "Docker" comme type
   - Connecter votre repository Git
   - Configurer les variables d'environnement (voir ci-dessous)

### Option 2 : Déploiement manuel

1. **Connectez-vous à votre serveur Dokploy** via SSH

2. **Créez un répertoire pour le projet** :
   ```bash
   mkdir -p ~/readeck-todoist-sync
   cd ~/readeck-todoist-sync
   ```

3. **Copiez tous les fichiers** dans ce répertoire

4. **Dans l'interface Dokploy** :
   - Créer une nouvelle application
   - Choisir "Docker" comme type
   - Pointer vers le répertoire local

## 🔧 Configuration des variables d'environnement

Dans Dokploy, configurez les variables d'environnement suivantes :

### Variables Readeck
```
READECK_API_URL=https://votre-instance-readeck.com/api
READECK_API_TOKEN=votre_token_readeck
```

### Variables Todoist
```
TODOIST_API_TOKEN=votre_token_todoist
TODOIST_PROJECT_ID=votre_project_id
TODOIST_SECTION_ID=votre_section_id
```

### Comment obtenir ces valeurs ?

#### Readeck
1. Connectez-vous à votre instance Readeck
2. Allez dans Settings > API
3. Créez un nouveau token
4. L'URL de base est : `https://votre-domaine.com/api`

#### Todoist
1. **API Token** : 
   - Allez sur https://todoist.com/app/settings/integrations/developer
   - Copiez votre "API token"

2. **Project ID** :
   - Exécutez ce script pour lister vos projets :
   ```bash
   curl -X GET \
     https://api.todoist.com/rest/v2/projects \
     -H "Authorization: Bearer VOTRE_TOKEN"
   ```

3. **Section ID** :
   - Exécutez ce script (remplacez PROJECT_ID) :
   ```bash
   curl -X GET \
     https://api.todoist.com/rest/v2/sections?project_id=PROJECT_ID \
     -H "Authorization: Bearer VOTRE_TOKEN"
   ```

## ⏰ Planification

Le script s'exécute automatiquement **tous les mardis à 19h** (Europe/Paris).

Pour modifier la planification, éditez le fichier `crontab` :
```
# Format: minute heure jour_du_mois mois jour_de_la_semaine
0 19 * * 2 /app/readeck-to-todoist.sh >> /var/log/readeck-sync/sync.log 2>&1
```

Exemples d'autres planifications :
- Tous les jours à 20h : `0 20 * * *`
- Tous les lundis à 9h : `0 9 * * 1`
- Deux fois par semaine (mardi et vendredi) à 19h : `0 19 * * 2,5`

## 📊 Vérification et logs

### Voir les logs en temps réel
Dans Dokploy, allez dans votre application > Logs

### Vérifier l'exécution
Les logs sont stockés dans `/var/log/readeck-sync/sync.log` dans le conteneur.

Pour consulter les logs :
```bash
docker exec -it <container_name> cat /var/log/readeck-sync/sync.log
```

### Tester manuellement
Pour exécuter le script immédiatement sans attendre le cron :
```bash
docker exec -it <container_name> /app/readeck-to-todoist.sh
```

## 🔍 Dépannage

### Le conteneur ne démarre pas
- Vérifiez que toutes les variables d'environnement sont définies
- Consultez les logs de démarrage dans Dokploy

### Le cron ne s'exécute pas
- Vérifiez le fuseau horaire du conteneur
- Consultez les logs du cron : `docker exec -it <container_name> tail -f /var/log/readeck-sync/sync.log`

### Erreurs d'API
- Vérifiez que vos tokens sont valides
- Vérifiez que les IDs de projet et section sont corrects
- Testez manuellement le script

## 🏗️ Architecture

```
┌─────────────────┐
│   Dokploy       │
│  ┌───────────┐  │
│  │ Container │  │
│  │           │  │
│  │  Alpine   │  │
│  │  + cron   │  │
│  │  + bash   │  │
│  │  + curl   │  │
│  │  + jq     │  │
│  └─────┬─────┘  │
└────────┼────────┘
         │
    ┌────┴────┐
    │         │
┌───▼──┐  ┌──▼────┐
│Readeck│  │Todoist│
└───────┘  └───────┘
```

## 📝 Fonctionnement

1. **Chaque mardi à 19h**, le cron déclenche le script
2. Le script récupère les articles Readeck non archivés avec le label "en vrac"
3. Pour chaque article :
   - Création d'une tâche dans Todoist (format markdown avec lien)
   - Si succès : archivage de l'article sur Readeck
   - Si échec : log de l'erreur et passage à l'article suivant
4. Rapport final avec le nombre d'articles traités

## 🔄 Mise à jour

Pour mettre à jour le script après modification :

1. Modifiez les fichiers dans votre repository
2. Poussez les changements sur Git
3. Dans Dokploy : Redéployer l'application

Ou pour un déploiement manuel :
1. Reconstruisez l'image Docker
2. Redémarrez le conteneur dans Dokploy
