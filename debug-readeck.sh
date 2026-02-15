#!/bin/bash

#######################################
# Script de debug pour identifier le problème
#######################################

set -euo pipefail

echo "=== DEBUG Readeck API ==="
echo ""

# Vérification des variables
if [[ -z "${READECK_API_TOKEN:-}" ]]; then
    echo "❌ READECK_API_TOKEN non défini"
    exit 1
fi

echo "✓ Token défini (longueur: ${#READECK_API_TOKEN})"
echo ""

# Test 1: Appel basique sans filtres
echo "--- Test 1: Appel basique (limit=1) ---"
response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer ${READECK_API_TOKEN}" \
    -H "Accept: application/json" \
    "https://readeck.victorprouff.fr/api/bookmarks?limit=1")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

echo "HTTP Code: $http_code"
echo "Body length: ${#body} caractères"
echo "Body preview (100 premiers caractères):"
echo "$body" | head -c 100
echo ""
echo ""

# Test 2: Avec is_archived=false
echo "--- Test 2: Avec is_archived=false ---"
response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer ${READECK_API_TOKEN}" \
    -H "Accept: application/json" \
    "https://readeck.victorprouff.fr/api/bookmarks?is_archived=false&limit=1")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

echo "HTTP Code: $http_code"
echo "Body length: ${#body} caractères"
echo "Body preview:"
echo "$body" | head -c 200
echo ""
echo ""

# Test 3: Avec le label "en vrac"
echo "--- Test 3: Avec label 'en vrac' ---"
response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer ${READECK_API_TOKEN}" \
    -H "Accept: application/json" \
    "https://readeck.victorprouff.fr/api/bookmarks?labels=%22en+vrac%22&is_archived=false")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

echo "HTTP Code: $http_code"
echo "Body length: ${#body} caractères"
echo ""
echo "Body complet:"
echo "$body"
echo ""

# Test 4: Vérification JSON
echo "--- Test 4: Validation JSON ---"
if command -v jq &> /dev/null; then
    if echo "$body" | jq empty 2>/dev/null; then
        echo "✓ JSON valide"
        
        # Compter les éléments
        count=$(echo "$body" | jq 'length' 2>/dev/null || echo "erreur")
        echo "Nombre d'articles: $count"
        
        if [[ "$count" != "erreur" ]] && [[ "$count" -gt 0 ]]; then
            echo ""
            echo "Premier article:"
            echo "$body" | jq '.[0]' 2>/dev/null || echo "Erreur lors de l'extraction"
        fi
    else
        echo "❌ JSON invalide"
        echo "Erreur jq:"
        echo "$body" | jq empty 2>&1 || true
    fi
else
    echo "⚠ jq non installé, impossible de valider le JSON"
fi

echo ""
echo "=== Fin du debug ==="