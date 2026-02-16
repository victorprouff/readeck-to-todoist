#!/bin/bash

#######################################
# Script de test local avec Docker
# Permet de tester le conteneur avant déploiement sur Dokploy
#######################################

set -e

echo "=== Test local du conteneur Readeck-Todoist Sync ==="
echo ""

# Vérification que Docker est installé
if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé"
    exit 1
fi

# Vérification des variables d'environnement
if [[ ! -f .env ]]; then
    echo "❌ Fichier .env non trouvé"
    echo ""
    echo "Créez un fichier .env avec le contenu suivant :"
    echo ""
    cat << 'EOF'
READECK_API_URL=https://votre-instance-readeck.com/api
READECK_API_TOKEN=votre_token_readeck
TODOIST_API_TOKEN=votre_token_todoist
TODOIST_PROJECT_ID=votre_project_id
TODOIST_SECTION_ID=votre_section_id
EOF
    echo ""
    exit 1
fi

echo "✓ Fichier .env trouvé"
echo ""

# Construction de l'image
echo "📦 Construction de l'image Docker..."
docker build -t readeck-todoist-sync:test .

if [[ $? -ne 0 ]]; then
    echo "❌ Échec de la construction de l'image"
    exit 1
fi

echo "✓ Image construite avec succès"
echo ""

# Question : test immédiat ou test du cron ?
echo "Que voulez-vous tester ?"
echo "1) Exécution immédiate du script (test rapide)"
echo "2) Démarrage du conteneur avec cron (test complet)"
echo ""
read -p "Votre choix (1 ou 2) : " choice

case $choice in
    1)
        echo ""
        echo "🚀 Exécution immédiate du script..."
        docker run --rm \
            --env-file .env \
            readeck-todoist-sync:test \
            /app/readeck-to-todoist.sh
        ;;
    2)
        echo ""
        echo "🚀 Démarrage du conteneur avec cron..."
        echo "Le conteneur va démarrer et attendre le prochain mardi à 19h"
        echo "Appuyez sur Ctrl+C pour arrêter"
        echo ""
        docker run --rm \
            --name readeck-todoist-sync-test \
            --env-file .env \
            readeck-todoist-sync:test
        ;;
    *)
        echo "❌ Choix invalide"
        exit 1
        ;;
esac
