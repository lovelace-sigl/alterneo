#!/bin/sh
# ---------------------------------------------------------------------------
# Création des bases et des comptes de service — ADR-002
#
# ADR-002 : UN serveur PostgreSQL partagé, UNE base et UN compte par
# microservice. Chaque compte ne peut voir que sa propre base : si le
# service Projets est compromis, il n'atteint pas les données des apprentis.
#
# Pourquoi un script shell et non un fichier .sql : le dépôt est PUBLIC.
# Un .sql contenant « CREATE USER ... WITH PASSWORD 'xxx' » serait un
# secret versionné. Ici le mot de passe arrive par la variable
# d'environnement SERVICE_DB_PASSWORD, que docker-compose lit dans .env
# (fichier ignoré par git). Rien de sensible n'entre dans l'historique.
#
# Écrit en sh POSIX, et non en bash : l'image postgres:16-alpine est
# minimale et on ne suppose pas que bash s'y trouve.
#
# /!\ CE SCRIPT NE S'EXÉCUTE QU'UNE SEULE FOIS : l'entrypoint PostgreSQL
#     ne lance les scripts de /docker-entrypoint-initdb.d/ qu'au premier
#     démarrage, quand le volume de données est vide. Si tu modifies ce
#     fichier ensuite, il ne rejouera pas tant que tu n'auras pas fait :
#
#         docker compose down -v && docker compose up
#
#     (le -v efface le volume, donc TOUTES les données locales)
#
# Les bases Réunions & documents et Notifications ne sont pas ici : ces
# deux services utilisent MongoDB (ADR-002), qui arrivera au Sprint 2.
# ---------------------------------------------------------------------------
set -eu

: "${POSTGRES_USER:?POSTGRES_USER doit être fourni par l'image postgres}"
: "${SERVICE_DB_PASSWORD:?SERVICE_DB_PASSWORD doit être fourni par docker-compose}"

# creer_base <nom_de_base> <nom_de_compte>
creer_base () {
  echo "  -> base $1, compte $2"

  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<SQL
CREATE DATABASE $1;
CREATE USER $2 WITH PASSWORD '$SERVICE_DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $1 TO $2;
SQL

  # Depuis PostgreSQL 15, un compte qui n'est pas propriétaire du schéma
  # « public » ne peut plus y créer de table. Sans ces deux ordres, le
  # service obtiendrait « permission denied for schema public » au premier
  # démarrage d'Hibernate ou de Flyway.
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$1" <<SQL
ALTER SCHEMA public OWNER TO $2;
GRANT ALL ON SCHEMA public TO $2;
SQL
}

echo "== Création des bases Alterneo (ADR-002) =="

creer_base apprentis_db     apprentis       # Apprentis et alternance   (Sprint 1)
creer_base keycloak_db      keycloak        # Keycloak (recette et production)
creer_base projets_db       projets         # Projets                   (Sprint 2)
creer_base ressources_db    ressources      # Ressources et architecture (Sprint 3)
creer_base appreciations_db appreciations   # Appréciations             (Sprint 3)

echo "== Cinq bases créées =="
