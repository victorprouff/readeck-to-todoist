FROM alpine:3.19

# Installation des dépendances
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    dcron \
    tzdata

# Configuration du timezone
ENV TZ=Europe/Paris
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Création du répertoire de travail
WORKDIR /app

# Copie du script
COPY readeck-to-todoist.sh /app/readeck-to-todoist.sh
RUN chmod +x /app/readeck-to-todoist.sh

# Copie du fichier de cron
COPY crontab /etc/crontabs/root

# Création du répertoire pour les logs
RUN mkdir -p /var/log/readeck-sync

# Script d'entrée pour démarrer cron
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
