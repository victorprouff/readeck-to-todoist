#!/bin/bash

#######################################
# Script de synchronisation Readeck -> Todoist
# Récupère les articles non archivés avec le label "en vrac"
# et les ajoute comme tâches dans Todoist
#######################################

set -euo pipefail

# Mode debug (décommentez pour activer)
# set -x

# Configuration
READECK_API_URL="https://readeck.victorprouff.fr/api"
TODOIST_PROJECT_ID="2332182173"
TODOIST_SECTION_ID="179438112"

# Variables d'environnement requises
# READECK_API_TOKEN : Token Bearer pour l'API Readeck
# TODOIST_API_TOKEN : Token pour l'API Todoist

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction de log
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérification des variables d'environnement
check_env_vars() {
    if [[ -z "${READECK_API_TOKEN:-}" ]]; then
        log_error "La variable d'environnement READECK_API_TOKEN n'est pas définie"
        exit 1
    fi
    
    if [[ -z "${TODOIST_API_TOKEN:-}" ]]; then
        log_error "La variable d'environnement TODOIST_API_TOKEN n'est pas définie"
        exit 1
    fi
}

# Vérification des dépendances
check_dependencies() {
    local missing_deps=0
    
    if ! command -v curl &> /dev/null; then
        log_error "curl n'est pas installé"
        missing_deps=1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq n'est pas installé. Installez-le avec: sudo apt-get install jq"
        missing_deps=1
    fi
    
    if [[ $missing_deps -eq 1 ]]; then
        exit 1
    fi
}

# Récupération des articles depuis Readeck
fetch_readeck_articles() {
    log_info "Récupération des articles depuis Readeck..." >&2
    
    local response
    response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer ${READECK_API_TOKEN}" \
        -H "Accept: application/json" \
        "${READECK_API_URL}/bookmarks?labels=%22en+vrac%22&is_archived=false")
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')
    
    # Logs envoyés sur stderr pour ne pas polluer stdout
    log_info "Code HTTP reçu: $http_code" >&2
    log_info "Longueur de la réponse: ${#body} caractères" >&2
    
    if [[ "$http_code" -ne 200 ]]; then
        log_error "Erreur lors de la récupération des articles (HTTP $http_code)" >&2
        log_error "Réponse: $body" >&2
        exit 1
    fi
    
    # Vérifier que la réponse n'est pas vide
    if [[ -z "$body" ]]; then
        log_error "Réponse vide de l'API Readeck" >&2
        exit 1
    fi
    
    # Vérifier que c'est du JSON valide
    if ! echo "$body" | jq empty 2>/dev/null; then
        log_error "Réponse JSON invalide de Readeck" >&2
        log_error "Réponse brute: ${body:0:500}..." >&2
        exit 1
    fi
    
    # IMPORTANT: Retourner UNIQUEMENT le body sur stdout
    echo "$body"
}

# Ajout d'une tâche dans Todoist
add_todoist_task() {
    local title="$1"
    local url="$2"
    local bookmark_id="$3"
    
    # Format markdown: [Titre](lien)
    local content="[$title]($url)"
    
    log_info "Ajout de la tâche: $title"
    
    local response
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Bearer ${TODOIST_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"content\": $(echo "$content" | jq -Rs .),
            \"project_id\": \"${TODOIST_PROJECT_ID}\",
            \"section_id\": \"${TODOIST_SECTION_ID}\"
        }" \
        "https://api.todoist.com/rest/v2/tasks")
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')
    
    if [[ "$http_code" -eq 200 ]]; then
        log_info "✓ Tâche ajoutée avec succès"
        return 0
    else
        log_error "✗ Erreur lors de l'ajout de la tâche (HTTP $http_code)"
        log_error "Réponse: $body"
        return 1
    fi
}

# Fonction principale
main() {
    log_info "=== Démarrage de la synchronisation Readeck -> Todoist ==="
    
    check_env_vars
    check_dependencies
    
    # Récupération des articles
    local articles
    articles=$(fetch_readeck_articles)
    
    log_info "Articles récupérés avec succès"
    
    # Comptage des articles
    local article_count
    article_count=$(echo "$articles" | jq 'length')
    
    log_info "Nombre d'articles trouvés: $article_count"
    
    if [[ "$article_count" -eq 0 ]]; then
        log_info "Aucun article à traiter. Fin du script."
        exit 0
    fi
    
    # Traitement de chaque article
    local success_count=0
    local error_count=0
    
    echo "$articles" | jq -c '.[]' | while IFS= read -r article; do
        local title
        title=$(echo "$article" | jq -r '.title')
        local url
        url=$(echo "$article" | jq -r '.url')
        local bookmark_id
        bookmark_id=$(echo "$article" | jq -r '.id')
        
        # Validation des données
        if [[ -z "$title" || "$title" == "null" ]]; then
            log_warn "Article sans titre (ID: $bookmark_id), ignoré"
            continue
        fi
        
        if [[ -z "$url" || "$url" == "null" ]]; then
            log_warn "Article sans URL (ID: $bookmark_id), ignoré"
            continue
        fi
        
        # Ajout dans Todoist
        if add_todoist_task "$title" "$url" "$bookmark_id"; then
            ((success_count++)) || true
        else
            ((error_count++)) || true
        fi
        
        # Petite pause pour éviter de surcharger l'API
        sleep 0.5
    done
    
    log_info "=== Synchronisation terminée ==="
    log_info "Articles traités avec succès: $success_count"
    if [[ $error_count -gt 0 ]]; then
        log_warn "Articles en erreur: $error_count"
    fi
}

# Exécution du script
main "$@"