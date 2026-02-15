#!/bin/bash

#######################################
# Script de test de configuration
# Vérifie que tout est bien configuré avant d'exécuter le script principal
#######################################

set -euo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Test de configuration Readeck → Todoist ===${NC}\n"

# Test 1: Variables d'environnement
echo -e "${BLUE}[1/5]${NC} Vérification des variables d'environnement..."

if [[ -n "${READECK_API_URL:-}" ]]; then
    echo -e "  ${GREEN}✓${NC} READECK_API_URL défini : ${READECK_API_URL}"
else
    echo -e "  ${RED}✗${NC} READECK_API_URL non défini"
    echo -e "    ${YELLOW}→${NC} Définissez la variable: export READECK_API_URL='https://readeck.example.com/api'"
fi

if [[ -n "${READECK_API_TOKEN:-}" ]]; then
    echo -e "  ${GREEN}✓${NC} READECK_API_TOKEN défini (${#READECK_API_TOKEN} caractères)"
else
    echo -e "  ${RED}✗${NC} READECK_API_TOKEN non défini"
    echo -e "    ${YELLOW}→${NC} Définissez la variable: export READECK_API_TOKEN='votre_token'"
fi

if [[ -n "${TODOIST_API_TOKEN:-}" ]]; then
    echo -e "  ${GREEN}✓${NC} TODOIST_API_TOKEN défini (${#TODOIST_API_TOKEN} caractères)"
else
    echo -e "  ${RED}✗${NC} TODOIST_API_TOKEN non défini"
    echo -e "    ${YELLOW}→${NC} Définissez la variable: export TODOIST_API_TOKEN='votre_token'"
fi

if [[ -n "${TODOIST_PROJECT_ID:-}" ]]; then
    echo -e "  ${GREEN}✓${NC} TODOIST_PROJECT_ID défini : ${TODOIST_PROJECT_ID}"
else
    echo -e "  ${RED}✗${NC} TODOIST_PROJECT_ID non défini"
    echo -e "    ${YELLOW}→${NC} Définissez la variable: export TODOIST_PROJECT_ID='project_id'"
fi

if [[ -n "${TODOIST_SECTION_ID:-}" ]]; then
    echo -e "  ${GREEN}✓${NC} TODOIST_SECTION_ID défini : ${TODOIST_SECTION_ID}"
else
    echo -e "  ${RED}✗${NC} TODOIST_SECTION_ID non défini"
    echo -e "    ${YELLOW}→${NC} Définissez la variable: export TODOIST_SECTION_ID='section_ID'"
fi

# Test 2: Dépendances
echo -e "\n${BLUE}[2/5]${NC} Vérification des dépendances..."
if command -v curl &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} curl installé ($(curl --version | head -n1))"
else
    echo -e "  ${RED}✗${NC} curl non installé"
    echo -e "    ${YELLOW}→${NC} Installez avec: sudo apt-get install curl"
fi

if command -v jq &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} jq installé ($(jq --version))"
else
    echo -e "  ${RED}✗${NC} jq non installé"
    echo -e "    ${YELLOW}→${NC} Installez avec: sudo apt-get install jq"
fi

# Test 3: Connexion Readeck
if [[ -n "${READECK_API_URL:-}" ]] && [[ -n "${READECK_API_TOKEN:-}" ]] && command -v curl &> /dev/null; then
    echo -e "\n${BLUE}[3/5]${NC} Test de connexion à Readeck..."
    
    response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer ${READECK_API_TOKEN}" \
        -H "Accept: application/json" \
        "${READECK_API_URL}/bookmarks?limit=1" 2>&1)
    
    http_code=$(echo "$response" | tail -n1)
    
    if [[ "$http_code" -eq 200 ]]; then
        echo -e "  ${GREEN}✓${NC} Connexion à Readeck réussie (HTTP 200)"
    elif [[ "$http_code" -eq 401 ]]; then
        echo -e "  ${RED}✗${NC} Erreur d'authentification Readeck (HTTP 401)"
        echo -e "    ${YELLOW}→${NC} Vérifiez votre token READECK_API_TOKEN"
    else
        echo -e "  ${RED}✗${NC} Erreur de connexion à Readeck (HTTP $http_code)"
    fi
else
    echo -e "\n${BLUE}[3/5]${NC} Test de connexion à Readeck..."
    echo -e "  ${YELLOW}⊘${NC} Test ignoré (prérequis manquants)"
fi

# Test 4: Connexion Todoist
if [[ -n "${TODOIST_API_TOKEN:-}" ]] && command -v curl &> /dev/null; then
    echo -e "\n${BLUE}[4/5]${NC} Test de connexion à Todoist..."
    
    response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer ${TODOIST_API_TOKEN}" \
        "https://api.todoist.com/rest/v2/projects" 2>&1)
    
    http_code=$(echo "$response" | tail -n1)
    
    if [[ "$http_code" -eq 200 ]]; then
        echo -e "  ${GREEN}✓${NC} Connexion à Todoist réussie (HTTP 200)"
        
        # Vérifier que le projet existe
        if command -v jq &> /dev/null; then
            body=$(echo "$response" | sed '$d')
            project_exists=$(echo "$body" | jq -r '.[] | select(.id=="2332182173") | .name' 2>/dev/null || echo "")
            
            if [[ -n "$project_exists" ]]; then
                echo -e "  ${GREEN}✓${NC} Projet trouvé: $project_exists"
            else
                echo -e "  ${YELLOW}⚠${NC} Projet ID 2332182173 non trouvé dans votre compte"
                echo -e "    ${YELLOW}→${NC} Vérifiez l'ID du projet dans le script"
            fi
        fi
    elif [[ "$http_code" -eq 401 ]]; then
        echo -e "  ${RED}✗${NC} Erreur d'authentification Todoist (HTTP 401)"
        echo -e "    ${YELLOW}→${NC} Vérifiez votre token TODOIST_API_TOKEN"
    else
        echo -e "  ${RED}✗${NC} Erreur de connexion à Todoist (HTTP $http_code)"
    fi
else
    echo -e "\n${BLUE}[4/5]${NC} Test de connexion à Todoist..."
    echo -e "  ${YELLOW}⊘${NC} Test ignoré (prérequis manquants)"
fi

# Test 5: Vérification des articles Readeck
if [[ -n "${READECK_API_URL:-}" ]] && [[ -n "${READECK_API_TOKEN:-}" ]] && command -v curl &> /dev/null && command -v jq &> /dev/null; then
    echo -e "\n${BLUE}[5/5]${NC} Vérification des articles 'en vrac'..."
    
    response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer ${READECK_API_TOKEN}" \
        -H "Accept: application/json" \
        "${READECK_API_URL}/bookmarks?labels=%22en+vrac%22&is_archived=false" 2>&1)
    
    http_code=$(echo "$response" | tail -n1)
    
    if [[ "$http_code" -eq 200 ]]; then
        body=$(echo "$response" | sed '$d')
        count=$(echo "$body" | jq 'length')
        echo -e "  ${GREEN}✓${NC} $count article(s) trouvé(s) avec le label 'en vrac'"
        
        if [[ $count -gt 0 ]]; then
            echo -e "\n  ${BLUE}Aperçu des articles:${NC}"
            echo "$body" | jq -r '.[] | "  - \(.title)"' | head -n 3
            if [[ $count -gt 3 ]]; then
                echo "  ..."
            fi
        fi
    else
        echo -e "  ${RED}✗${NC} Erreur lors de la récupération des articles (HTTP $http_code)"
    fi
else
    echo -e "\n${BLUE}[5/5]${NC} Vérification des articles 'en vrac'..."
    echo -e "  ${YELLOW}⊘${NC} Test ignoré (prérequis manquants)"
fi

# Résumé
echo -e "\n${BLUE}=== Résumé ===${NC}"

all_ok=true
if [[ -z "${READECK_API_URL:-}" ]] || [[ -z "${READECK_API_TOKEN:-}" ]] || [[ -z "${TODOIST_API_TOKEN:-}" ]] || [[ -z "${TODOIST_PROJECT_ID:-}" ]] || [[ -z "${TODOIST_SECTION_ID:-}" ]]; then
    all_ok=false
fi
if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
    all_ok=false
fi

if [[ "$all_ok" == true ]]; then
    echo -e "${GREEN}✓ Configuration correcte !${NC}"
    echo -e "Vous pouvez exécuter le script principal: ${BLUE}./readeck-to-todoist.sh${NC}"
else
    echo -e "${YELLOW}⚠ Configuration incomplète${NC}"
    echo -e "Corrigez les erreurs ci-dessus avant d'exécuter le script principal."
fi

echo ""