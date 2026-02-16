#!/bin/bash
set -e

echo "=== Démarrage du service de synchronisation Readeck -> Todoist ==="
echo "Fuseau horaire: $(cat /etc/timezone)"
echo "Date/heure actuelle: $(date)"
echo ""

# Vérification des variables d'environnement
echo "Vérification de la configuration..."
if [[ -z "${READECK_API_URL}" ]]; then
    echo "ERREUR: READECK_API_URL non défini"
    exit 1
fi
if [[ -z "${READECK_API_TOKEN}" ]]; then
    echo "ERREUR: READECK_API_TOKEN non défini"
    exit 1
fi
if [[ -z "${TODOIST_API_TOKEN}" ]]; then
    echo "ERREUR: TODOIST_API_TOKEN non défini"
    exit 1
fi
if [[ -z "${TODOIST_PROJECT_ID}" ]]; then
    echo "ERREUR: TODOIST_PROJECT_ID non défini"
    exit 1
fi
if [[ -z "${TODOIST_SECTION_ID}" ]]; then
    echo "ERREUR: TODOIST_SECTION_ID non défini"
    exit 1
fi

echo "✓ Configuration valide"
echo ""

# Affichage de la planification cron
echo "Planification du cron:"
cat /etc/crontabs/root
echo ""

# Exportation des variables d'environnement pour cron
# Cron ne charge pas automatiquement les variables d'environnement
env | grep -E '^(READECK_|TODOIST_)' > /etc/environment

echo "Démarrage du service cron en premier plan..."
# Démarrage de crond en mode foreground
exec crond -f -l 2
