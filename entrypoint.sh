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
echo "En attente de déclenchement par Dokploy..."
exec sleep infinity
