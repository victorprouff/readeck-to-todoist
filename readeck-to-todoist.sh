#!/bin/bash

#######################################
# Script de synchronisation de la veille "en vrac" -> Todoist
#
# Source Readeck :
#   Récupère les articles non archivés avec le label "en vrac"
#   Les ajoute comme tâches dans Todoist
#   Archive les articles sur Readeck après ajout réussi
#
# Source YouTube :
#   Récupère les vidéos d'une playlist
#   Les ajoute comme tâches dans Todoist
#   Retire les vidéos de la playlist après ajout réussi
#
# Chaque source est activée uniquement si ses variables sont définies.
#######################################

set -euo pipefail

# Mode debug (décommentez pour activer)
# set -x

# Configuration
# Ces valeurs doivent être définies comme variables d'environnement :
# TODOIST_API_TOKEN : Token pour l'API Todoist
# TODOIST_PROJECT_ID : ID du projet Todoist
# TODOIST_SECTION_ID : ID de la section Todoist
#
# Source Readeck (optionnelle) :
# READECK_API_URL : URL de base de votre instance Readeck
# READECK_API_TOKEN : Token Bearer pour l'API Readeck
#
# Source YouTube (optionnelle) :
# YOUTUBE_PLAYLIST_ID : ID de la playlist à vider
# YOUTUBE_CLIENT_ID : Client ID OAuth Google
# YOUTUBE_CLIENT_SECRET : Client secret OAuth Google
# YOUTUBE_REFRESH_TOKEN : Refresh token OAuth (voir get-youtube-refresh-token.sh)
# YOUTUBE_TODOIST_SECTION_ID : Section Todoist des vidéos (défaut : TODOIST_SECTION_ID)
#
# DRY_RUN=1 : effectue uniquement les lectures, sans rien ajouter, archiver ni retirer

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

READECK_ENABLED=0
YOUTUBE_ENABLED=0
DRY_RUN="${DRY_RUN:-0}"

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

# Vérifie un groupe de variables : retourne 0 si toutes sont définies,
# 1 si aucune ne l'est, et quitte si le groupe est partiellement défini
check_var_group() {
    local group_name="$1"
    shift
    local defined=0
    local missing=()

    for var in "$@"; do
        if [[ -n "${!var:-}" ]]; then
            ((defined++)) || true
        else
            missing+=("$var")
        fi
    done

    if [[ $defined -eq $# ]]; then
        return 0
    fi

    if [[ $defined -eq 0 ]]; then
        return 1
    fi

    for var in "${missing[@]}"; do
        log_error "Source $group_name : la variable d'environnement $var n'est pas définie"
    done
    log_error "Veuillez définir toutes les variables de la source $group_name (ou aucune pour la désactiver)"
    exit 1
}

# Vérification des variables d'environnement
check_env_vars() {
    local missing_vars=0

    if [[ -z "${TODOIST_API_TOKEN:-}" ]]; then
        log_error "La variable d'environnement TODOIST_API_TOKEN n'est pas définie"
        missing_vars=1
    fi

    if [[ -z "${TODOIST_PROJECT_ID:-}" ]]; then
        log_error "La variable d'environnement TODOIST_PROJECT_ID n'est pas définie"
        missing_vars=1
    fi

    if [[ -z "${TODOIST_SECTION_ID:-}" ]]; then
        log_error "La variable d'environnement TODOIST_SECTION_ID n'est pas définie"
        missing_vars=1
    fi

    if [[ $missing_vars -eq 1 ]]; then
        log_error "Veuillez définir toutes les variables d'environnement requises"
        exit 1
    fi

    if check_var_group "Readeck" READECK_API_URL READECK_API_TOKEN; then
        READECK_ENABLED=1
        # Supprime un éventuel slash final pour éviter les "//bookmarks"
        READECK_API_URL="${READECK_API_URL%/}"
    fi

    if check_var_group "YouTube" YOUTUBE_PLAYLIST_ID YOUTUBE_CLIENT_ID YOUTUBE_CLIENT_SECRET YOUTUBE_REFRESH_TOKEN; then
        YOUTUBE_ENABLED=1
        YOUTUBE_TODOIST_SECTION_ID="${YOUTUBE_TODOIST_SECTION_ID:-$TODOIST_SECTION_ID}"
    fi

    if [[ $READECK_ENABLED -eq 0 && $YOUTUBE_ENABLED -eq 0 ]]; then
        log_error "Aucune source configurée : définissez les variables Readeck et/ou YouTube"
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

# Ajout d'une tâche dans Todoist
add_todoist_task() {
    local title="$1"
    local url="$2"
    local section_id="$3"

    # Format markdown: [Titre](lien)
    local content="[$title]($url)"

    log_info "Ajout de la tâche: $title"

    if [[ "$DRY_RUN" == "1" ]]; then
        log_warn "[DRY RUN] Tâche non ajoutée : $content (section $section_id)"
        return 0
    fi

    # Générer un UUID pour la commande et un temp_id
    local uuid
    uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(date +%s)-$$-$RANDOM")
    local temp_id
    temp_id=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "temp-$(date +%s)-$$-$RANDOM")

    local response
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Bearer ${TODOIST_API_TOKEN}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "commands=[{
            \"type\": \"item_add\",
            \"temp_id\": \"${temp_id}\",
            \"uuid\": \"${uuid}\",
            \"args\": {
                \"content\": $(echo "$content" | jq -Rs .),
                \"project_id\": \"${TODOIST_PROJECT_ID}\",
                \"section_id\": \"${section_id}\"
            }
        }]" \
        "https://api.todoist.com/api/v1/sync")

    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" -eq 200 ]]; then
        # Vérifier le statut de la commande dans la réponse
        local sync_status
        sync_status=$(echo "$body" | jq -r ".sync_status.\"${uuid}\"" 2>/dev/null || echo "error")

        if [[ "$sync_status" == "ok" ]]; then
            log_info "✓ Tâche ajoutée avec succès"
            return 0
        else
            log_error "✗ Erreur dans la réponse Todoist: $sync_status"
            log_error "Réponse: $body"
            return 1
        fi
    else
        log_error "✗ Erreur lors de l'ajout de la tâche (HTTP $http_code)"
        log_error "Réponse: $body"
        return 1
    fi
}

#######################################
# Readeck
#######################################

# Récupération des articles depuis Readeck
fetch_readeck_articles() {
    log_info "Récupération des articles depuis Readeck (${READECK_API_URL})..." >&2

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
        return 1
    fi

    # Vérifier que la réponse n'est pas vide
    if [[ -z "$body" ]]; then
        log_error "Réponse vide de l'API Readeck" >&2
        return 1
    fi

    # Vérifier que c'est du JSON valide
    if ! echo "$body" | jq empty 2>/dev/null; then
        log_error "Réponse JSON invalide de Readeck" >&2
        log_error "Réponse brute: ${body:0:500}..." >&2
        return 1
    fi

    # IMPORTANT: Retourner UNIQUEMENT le body sur stdout
    echo "$body"
}

# Archivage d'un article sur Readeck
archive_readeck_article() {
    local bookmark_id="$1"
    local title="$2"

    log_info "Archivage de l'article sur Readeck: $title"

    if [[ "$DRY_RUN" == "1" ]]; then
        log_warn "[DRY RUN] Article non archivé"
        return 0
    fi

    local response
    response=$(curl -s -w "\n%{http_code}" \
        -X PATCH \
        -H "Authorization: Bearer ${READECK_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "{\"is_archived\": true}" \
        "${READECK_API_URL}/bookmarks/${bookmark_id}")

    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" -eq 200 ]]; then
        log_info "✓ Article archivé sur Readeck"
        return 0
    else
        log_error "✗ Erreur lors de l'archivage sur Readeck (HTTP $http_code)"
        log_error "Réponse: $body"
        return 1
    fi
}

# Synchronisation Readeck -> Todoist
sync_readeck() {
    log_info "--- Source Readeck ---"

    # Récupération des articles
    local articles
    articles=$(fetch_readeck_articles) || return 1

    log_info "Articles récupérés avec succès"

    # Comptage des articles
    local article_count
    article_count=$(echo "$articles" | jq 'length')

    log_info "Nombre d'articles trouvés: $article_count"

    if [[ "$article_count" -eq 0 ]]; then
        log_info "Aucun article à traiter."
        return 0
    fi

    # Traitement de chaque article
    local success_count=0
    local error_count=0
    local archived_count=0

    while IFS= read -r article; do
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
        if add_todoist_task "$title" "$url" "$TODOIST_SECTION_ID"; then
            ((success_count++)) || true

            # Archivage sur Readeck si l'ajout dans Todoist a réussi
            if archive_readeck_article "$bookmark_id" "$title"; then
                ((archived_count++)) || true
            else
                log_warn "L'article a été ajouté à Todoist mais n'a pas pu être archivé sur Readeck"
            fi
        else
            ((error_count++)) || true
        fi

        # Petite pause pour éviter de surcharger l'API
        sleep 0.5
    done < <(echo "$articles" | jq -c '.[]')

    log_info "Articles traités avec succès: $success_count"
    log_info "Articles archivés sur Readeck: $archived_count"
    if [[ $error_count -gt 0 ]]; then
        log_warn "Articles en erreur: $error_count"
        return 1
    fi
}

#######################################
# YouTube
#######################################

# Échange du refresh token contre un access token
get_youtube_access_token() {
    local response
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        --data-urlencode "client_id=${YOUTUBE_CLIENT_ID}" \
        --data-urlencode "client_secret=${YOUTUBE_CLIENT_SECRET}" \
        --data-urlencode "refresh_token=${YOUTUBE_REFRESH_TOKEN}" \
        --data-urlencode "grant_type=refresh_token" \
        "https://oauth2.googleapis.com/token")

    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" -ne 200 ]]; then
        log_error "Erreur lors de l'obtention du token YouTube (HTTP $http_code)" >&2
        log_error "Réponse: $body" >&2
        if echo "$body" | grep -q "invalid_grant"; then
            log_error "Le refresh token est expiré ou révoqué : relancez get-youtube-refresh-token.sh" >&2
        fi
        return 1
    fi

    echo "$body" | jq -r '.access_token'
}

# Récupération de toutes les vidéos de la playlist (gère la pagination)
# Retourne un tableau JSON de playlistItems
fetch_youtube_playlist_items() {
    local access_token="$1"

    log_info "Récupération des vidéos de la playlist ${YOUTUBE_PLAYLIST_ID}..." >&2

    local items="[]"
    local page_token=""

    while :; do
        local page_args=()
        if [[ -n "$page_token" ]]; then
            page_args=(--data-urlencode "pageToken=${page_token}")
        fi

        local response
        response=$(curl -s -w "\n%{http_code}" -G \
            -H "Authorization: Bearer ${access_token}" \
            -H "Accept: application/json" \
            --data-urlencode "part=snippet" \
            --data-urlencode "playlistId=${YOUTUBE_PLAYLIST_ID}" \
            --data-urlencode "maxResults=50" \
            "${page_args[@]}" \
            "https://www.googleapis.com/youtube/v3/playlistItems")

        local http_code
        http_code=$(echo "$response" | tail -n1)
        local body
        body=$(echo "$response" | sed '$d')

        if [[ "$http_code" -ne 200 ]]; then
            log_error "Erreur lors de la récupération de la playlist (HTTP $http_code)" >&2
            log_error "Réponse: $body" >&2
            return 1
        fi

        items=$(jq -c --argjson acc "$items" '$acc + (.items // [])' <<< "$body")
        page_token=$(jq -r '.nextPageToken // empty' <<< "$body")

        if [[ -z "$page_token" ]]; then
            break
        fi
    done

    echo "$items"
}

# Retrait d'une vidéo de la playlist
remove_youtube_playlist_item() {
    local access_token="$1"
    local item_id="$2"
    local title="$3"

    log_info "Retrait de la vidéo de la playlist: $title"

    if [[ "$DRY_RUN" == "1" ]]; then
        log_warn "[DRY RUN] Vidéo non retirée"
        return 0
    fi

    local response
    response=$(curl -s -w "\n%{http_code}" -G \
        -X DELETE \
        -H "Authorization: Bearer ${access_token}" \
        --data-urlencode "id=${item_id}" \
        "https://www.googleapis.com/youtube/v3/playlistItems")

    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" -eq 204 ]]; then
        log_info "✓ Vidéo retirée de la playlist"
        return 0
    else
        log_error "✗ Erreur lors du retrait de la vidéo (HTTP $http_code)"
        log_error "Réponse: $body"
        return 1
    fi
}

# Synchronisation YouTube -> Todoist
sync_youtube() {
    log_info "--- Source YouTube ---"

    local access_token
    access_token=$(get_youtube_access_token) || return 1

    local videos
    videos=$(fetch_youtube_playlist_items "$access_token") || return 1

    local video_count
    video_count=$(echo "$videos" | jq 'length')

    log_info "Nombre de vidéos trouvées: $video_count"

    if [[ "$video_count" -eq 0 ]]; then
        log_info "Aucune vidéo à traiter."
        return 0
    fi

    local success_count=0
    local error_count=0
    local removed_count=0

    while IFS= read -r video; do
        local item_id
        item_id=$(echo "$video" | jq -r '.id')
        local title
        title=$(echo "$video" | jq -r '.snippet.title')
        local video_id
        video_id=$(echo "$video" | jq -r '.snippet.resourceId.videoId')
        local channel
        channel=$(echo "$video" | jq -r '.snippet.videoOwnerChannelTitle // empty')

        # Les vidéos supprimées ou privées n'ont pas de chaîne propriétaire
        if [[ -z "$channel" ]]; then
            log_warn "Vidéo indisponible ($title, ID: $video_id), ignorée"
            continue
        fi

        if add_todoist_task "$title" "https://www.youtube.com/watch?v=${video_id}" "$YOUTUBE_TODOIST_SECTION_ID"; then
            ((success_count++)) || true

            # Retrait de la playlist si l'ajout dans Todoist a réussi
            if remove_youtube_playlist_item "$access_token" "$item_id" "$title"; then
                ((removed_count++)) || true
            else
                log_warn "La vidéo a été ajoutée à Todoist mais n'a pas pu être retirée de la playlist"
            fi
        else
            ((error_count++)) || true
        fi

        # Petite pause pour éviter de surcharger l'API
        sleep 0.5
    done < <(echo "$videos" | jq -c '.[]')

    log_info "Vidéos traitées avec succès: $success_count"
    log_info "Vidéos retirées de la playlist: $removed_count"
    if [[ $error_count -gt 0 ]]; then
        log_warn "Vidéos en erreur: $error_count"
        return 1
    fi
}

# Fonction principale
main() {
    log_info "=== Démarrage de la synchronisation -> Todoist ==="

    check_env_vars
    check_dependencies

    if [[ "$DRY_RUN" == "1" ]]; then
        log_warn "Mode DRY RUN : aucune modification ne sera effectuée"
    fi

    local failed=0

    if [[ $READECK_ENABLED -eq 1 ]]; then
        sync_readeck || failed=1
    else
        log_info "Source Readeck non configurée, ignorée"
    fi

    if [[ $YOUTUBE_ENABLED -eq 1 ]]; then
        sync_youtube || failed=1
    else
        log_info "Source YouTube non configurée, ignorée"
    fi

    log_info "=== Synchronisation terminée ==="

    exit $failed
}

# Exécution du script
main "$@"
