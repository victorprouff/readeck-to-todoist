#!/bin/bash

#######################################
# Script pour convertir les anciens IDs Todoist v1 vers v2
#######################################

set -euo pipefail

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Conversion des IDs Todoist ===${NC}\n"

# Vérifier le token
if [[ -z "${TODOIST_API_TOKEN:-}" ]]; then
    echo -e "${RED}Erreur: TODOIST_API_TOKEN non défini${NC}"
    exit 1
fi

# IDs à convertir
OLD_PROJECT_ID="2332182173"
OLD_SECTION_ID="181074705"

echo "Conversion des IDs..."
echo ""

# Appel à l'API pour obtenir les mappings
response=$(curl -s -X GET \
    "https://api.todoist.com/api/v1/id-mappings?ids=${OLD_PROJECT_ID},${OLD_SECTION_ID}" \
    -H "Authorization: Bearer ${TODOIST_API_TOKEN}")

echo -e "${GREEN}Réponse de l'API:${NC}"
echo "$response" | jq .

# Extraire les nouveaux IDs
new_project_id=$(echo "$response" | jq -r ".\"${OLD_PROJECT_ID}\" // empty")
new_section_id=$(echo "$response" | jq -r ".\"${OLD_SECTION_ID}\" // empty")

echo ""
echo -e "${GREEN}=== Résultats ===${NC}"
echo ""
echo "Ancien Project ID: ${OLD_PROJECT_ID}"
echo "Nouveau Project ID: ${new_project_id:-Non trouvé}"
echo ""
echo "Ancien Section ID: ${OLD_SECTION_ID}"
echo "Nouveau Section ID: ${new_section_id:-Non trouvé}"
echo ""

if [[ -n "$new_project_id" ]] && [[ -n "$new_section_id" ]]; then
    echo -e "${GREEN}✓ Conversion réussie !${NC}"
    echo ""
    echo "Mettez à jour votre script avec ces nouveaux IDs:"
    echo "TODOIST_PROJECT_ID=\"${new_project_id}\""
    echo "TODOIST_SECTION_ID=\"${new_section_id}\""
else
    echo -e "${RED}✗ Impossible de convertir certains IDs${NC}"
    echo ""
    echo "Essayez de récupérer vos projets et sections directement:"
    echo ""
    echo "# Liste des projets:"
    curl -s -X POST \
        "https://api.todoist.com/api/v1/sync" \
        -H "Authorization: Bearer ${TODOIST_API_TOKEN}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode 'sync_token=*' \
        --data-urlencode 'resource_types=["projects"]' | jq '.projects[] | {id, name}'
    
    echo ""
    echo "# Liste des sections:"
    curl -s -X POST \
        "https://api.todoist.com/api/v1/sync" \
        -H "Authorization: Bearer ${TODOIST_API_TOKEN}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode 'sync_token=*' \
        --data-urlencode 'resource_types=["sections"]' | jq '.sections[] | {id, name, project_id}'
fi