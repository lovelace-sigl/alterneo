#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Provisionnement de l'environnement de RECETTE sur Azure — Alterneo
#
# Crée le strict nécessaire pour faire tourner un microservice, et déploie
# un conteneur témoin pour prouver que l'URL publique répond. La vraie
# image (apprentis) sera déployée ensuite par le workflow GitHub Actions,
# depuis GitHub Container Registry.
#
# COÛT : pensé pour rester à 0 €.
#   - Pas de registre d'images Azure (ACR, payant) : on utilisera ghcr.io.
#   - Container Apps a une grille mensuelle gratuite. Le conteneur redescend
#     à ZÉRO réplica quand personne ne l'appelle (--min-replicas 0), donc il
#     ne consomme la grille que lorsqu'il est sollicité. En « toujours
#     allumé », il dépasserait la grille gratuite et serait facturé.
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

# Conteneur témoin, juste pour prouver la chaîne (page d'accueil sur le port 80).
# Le workflow le remplacera par ghcr.io/lovelace-sigl/apprentis (port 8081).
PLACEHOLDER_IMAGE="mcr.microsoft.com/k8se/quickstart:latest"
PLACEHOLDER_PORT="80"

echo "== Souscription =="
az account set --subscription "$SUBSCRIPTION_ID"
az account show --query "{nom:name, etat:state}" -o table

echo "== Extension et fournisseurs =="
az extension add --name containerapp --upgrade --only-show-errors
# Sur une souscription neuve, ces fournisseurs doivent être enregistrés.
# L'enregistrement peut prendre 1 à 2 minutes ; si une étape suivante
# échoue avec « provider not registered », attends un peu et relance.
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

echo "== Application conteneur (témoin) =="
if ! az containerapp show -n "$APP_NAME" -g "$RESOURCE_GROUP" &>/dev/null; then
  az containerapp create \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$ENVIRONMENT" \
    --image "$PLACEHOLDER_IMAGE" \
    --target-port "$PLACEHOLDER_PORT" \
    --ingress external \
    --min-replicas 0 \
    --max-replicas 1 \
    --cpu 0.25 \
    --memory 0.5Gi \
    -o table
else
  echo "  déjà présente."
fi

echo
echo "== Terminé =="
FQDN=$(az containerapp show -n "$APP_NAME" -g "$RESOURCE_GROUP" \
        --query properties.configuration.ingress.fqdn -o tsv)
echo "URL publique :  https://$FQDN"
echo
echo "Teste-la :      curl https://$FQDN"
echo "(première requête un peu lente : le conteneur redémarre depuis zéro)"
