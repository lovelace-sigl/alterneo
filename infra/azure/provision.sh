#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Provisionnement de l'environnement de RECETTE sur Azure — Alterneo
#
# Crée le strict nécessaire pour faire tourner un microservice, et donne à
# l'application sa FORME définitive : port d'écoute, réplicas, ressources.
# L'image, elle, est déployée par le workflow GitHub Actions depuis GitHub
# Container Registry.
#
# Répartition des rôles, à respecter :
#   · ici (provision.sh)        la forme de l'application — rejoué à la main,
#                               rarement, quand l'infrastructure change
#   · là (cd-recette.yml)       l'image seulement — rejoué à chaque fusion
#
# COÛT : pensé pour rester à 0 €.
#   - Pas de registre d'images Azure (ACR, payant) : on utilise ghcr.io.
#   - Container Apps a une grille mensuelle gratuite. Le conteneur redescend
#     à ZÉRO réplica quand personne ne l'appelle (--min-replicas 0), donc il
#     ne consomme la grille que lorsqu'il est sollicité. En « toujours
#     allumé », il dépasserait la grille gratuite et serait facturé.
#   - Pas encore de base de données en recette : à trancher au Sprint 2.
#   - À supprimer après la soutenance :  az group delete -n alterneo-recette
#
# Prérequis : az login déjà fait.
# Rejouable : relancer le script ne crée pas de doublon.
# ---------------------------------------------------------------------------
set -euo pipefail

# --- Paramètres ------------------------------------------------------------
SUBSCRIPTION_ID="b840c326-4a73-48d8-8c85-d6153df45ddd"
LOCATION="francecentral"          # données en France ; bascule sur westeurope en cas de quota
RESOURCE_GROUP="alterneo-recette"
ENVIRONMENT="alterneo-env"
APP_NAME="apprentis"
APP_PORT="8081"                   # le port sur lequel le vrai service écoute

# Image de départ, le temps que le premier déploiement pousse la vraie.
# Elle écoute sur 80 et ne répondra donc pas sur APP_PORT : c'est normal,
# l'URL ne renvoie quelque chose qu'après le premier passage du CD.
PLACEHOLDER_IMAGE="mcr.microsoft.com/k8se/quickstart:latest"

echo "== Souscription =="
az account set --subscription "$SUBSCRIPTION_ID"
az account show --query "{nom:name, etat:state}" -o table

echo "== Extension et fournisseurs =="
az extension add --name containerapp --upgrade --only-show-errors
# Sur une souscription neuve, ces fournisseurs doivent être enregistrés.
# --wait bloque jusqu'à la fin de l'enregistrement : sans lui, l'étape
# suivante échoue avec « provider not registered ».
az provider register --namespace Microsoft.App --wait --only-show-errors
az provider register --namespace Microsoft.OperationalInsights --wait --only-show-errors

echo "== Groupe de ressources =="
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" -o table

echo "== Environnement Container Apps =="
# Crée au passage un espace Log Analytics (grille gratuite de 5 Go/mois).
if ! az containerapp env show -n "$ENVIRONMENT" -g "$RESOURCE_GROUP" &>/dev/null; then
  az containerapp env create \
    --name "$ENVIRONMENT" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    -o table
else
  echo "  déjà présent."
fi

echo "== Application conteneur =="
if ! az containerapp show -n "$APP_NAME" -g "$RESOURCE_GROUP" &>/dev/null; then
  az containerapp create \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$ENVIRONMENT" \
    --image "$PLACEHOLDER_IMAGE" \
    --target-port "$APP_PORT" \
    --ingress external \
    --min-replicas 0 \
    --max-replicas 1 \
    --cpu 0.25 \
    --memory 0.5Gi \
    -o table
else
  echo "  déjà présente."
fi

echo "== Port d'ingress =="
# Rattrapage pour une application créée avant l'introduction de APP_PORT
# (elle avait été créée sur le port 80, celui de l'image de départ).
# Cette commande est ici, et PAS dans le workflow de déploiement : c'est de
# la forme, pas du déploiement. La rejouer à chaque fusion la faisait
# échouer régulièrement en ServerTimeout.
PORT_ACTUEL=$(az containerapp show -n "$APP_NAME" -g "$RESOURCE_GROUP" \
                --query properties.configuration.ingress.targetPort -o tsv)
if [ "$PORT_ACTUEL" != "$APP_PORT" ]; then
  echo "  $PORT_ACTUEL → $APP_PORT"
  az containerapp ingress update \
    --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" \
    --target-port "$APP_PORT" -o none
else
  echo "  déjà sur $APP_PORT."
fi

echo
echo "== Terminé =="
FQDN=$(az containerapp show -n "$APP_NAME" -g "$RESOURCE_GROUP" \
        --query properties.configuration.ingress.fqdn -o tsv)
echo "URL publique :  https://$FQDN/api/apprentis/ping"
echo
echo "Si l'application vient d'être créée, cette URL ne répond pas encore :"
echo "elle porte l'image de départ. Déclenche le déploiement pour y mettre"
echo "le vrai service :"
echo
echo "    gh workflow run \"CD recette\" --repo lovelace-sigl/alterneo --ref main"
