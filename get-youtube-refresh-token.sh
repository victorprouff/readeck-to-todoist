#!/bin/bash

#######################################
# Obtention d'un refresh token OAuth Google pour l'API YouTube
# À lancer une seule fois, en local, pour remplir YOUTUBE_REFRESH_TOKEN
#
# Prérequis : un client OAuth de type "Application de bureau" créé dans
# Google Cloud Console, avec l'API "YouTube Data API v3" activée.
#
# Usage : YOUTUBE_CLIENT_ID=... YOUTUBE_CLIENT_SECRET=... ./get-youtube-refresh-token.sh
#######################################

set -euo pipefail

if [[ -z "${YOUTUBE_CLIENT_ID:-}" || -z "${YOUTUBE_CLIENT_SECRET:-}" ]]; then
    echo "Définissez YOUTUBE_CLIENT_ID et YOUTUBE_CLIENT_SECRET avant de lancer ce script" >&2
    exit 1
fi

REDIRECT_URI="http://localhost:8080"
SCOPE="https://www.googleapis.com/auth/youtube"

auth_url="https://accounts.google.com/o/oauth2/v2/auth?client_id=${YOUTUBE_CLIENT_ID}&redirect_uri=$(jq -rn --arg v "$REDIRECT_URI" '$v|@uri')&response_type=code&scope=$(jq -rn --arg v "$SCOPE" '$v|@uri')&access_type=offline&prompt=consent"

echo "1. Ouvrez cette URL dans votre navigateur et autorisez l'accès :"
echo ""
echo "   $auth_url"
echo ""
echo "2. Le navigateur sera redirigé vers ${REDIRECT_URI}/?code=... (la page ne se chargera pas, c'est normal)."
echo "   Copiez l'URL complète de la barre d'adresse."
echo ""
read -r -p "URL de redirection : " redirect

code=$(echo "$redirect" | sed -n 's/.*[?&]code=\([^&]*\).*/\1/p')
if [[ -z "$code" ]]; then
    echo "Impossible de trouver le paramètre code dans l'URL" >&2
    exit 1
fi
# Le code est encodé dans l'URL (ex: 4%2F0A...)
code=$(printf '%b' "${code//%/\\x}")

response=$(curl -s -X POST \
    --data-urlencode "code=${code}" \
    --data-urlencode "client_id=${YOUTUBE_CLIENT_ID}" \
    --data-urlencode "client_secret=${YOUTUBE_CLIENT_SECRET}" \
    --data-urlencode "redirect_uri=${REDIRECT_URI}" \
    --data-urlencode "grant_type=authorization_code" \
    "https://oauth2.googleapis.com/token")

refresh_token=$(echo "$response" | jq -r '.refresh_token // empty')
if [[ -z "$refresh_token" ]]; then
    echo "Échec de l'échange du code :" >&2
    echo "$response" >&2
    exit 1
fi

echo ""
echo "✓ Refresh token obtenu. Ajoutez-le dans Dokploy :"
echo ""
echo "YOUTUBE_REFRESH_TOKEN=${refresh_token}"
