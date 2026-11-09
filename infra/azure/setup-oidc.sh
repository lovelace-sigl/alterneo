#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Connexion GitHub Actions → Azure, sans aucun secret stocké (OIDC)
#
# Au lieu de ranger un mot de passe Azure dans GitHub, on crée une IDENTITÉ
# MANAGÉE (une ressource Azure qu'on possède) et une CREDENTIAL FÉDÉRÉE :
# elle autorise les workflows de CE dépôt, sur CETTE branche, à prendre
# l'identité le temps d'un déploiement, via un jeton court. Rien de
# permanent à voler.
#
# On passe par une identité managée (et non une « app registration »)
# parce que le tenant ESEO bloque souvent la création d'app registrations
# pour les étudiants. L'identité, elle, est une ressource de TON groupe.
#
# Prérequis : az login fait, et provision.sh déjà passé (le groupe existe).
# Rejouable.
# ---------------------------------------------------------------------------
set -euo pipefail

SUBSCRIPTION_ID="b840c326-4a73-48d8-8c85-d6153df45ddd"
RESOURCE_GROUP="alterneo-recette"
IDENTITY="alterneo-github-deploy"
REPO="lovelace-sigl/alterneo"
BRANCH="main"

az account set --subscription "$SUBSCRIPTION_ID"

echo "== 1. Identité managée =="
if ! az identity show -g "$RESOURCE_GROUP" -n "$IDENTITY" &>/dev/null; then
  az identity create -g "$RESOURCE_GROUP" -n "$IDENTITY" -o table
else
  echo "  déjà présente."
fi

CLIENT_ID=$(az identity show -g "$RESOURCE_GROUP" -n "$IDENTITY" --query clientId -o tsv)
PRINCIPAL_ID=$(az identity show -g "$RESOURCE_GROUP" -n "$IDENTITY" --query principalId -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "== 2. Credential fédérée (dépôt $REPO, branche $BRANCH) =="
if ! az identity federated-credential show \
      --name "github-$BRANCH" --identity-name "$IDENTITY" -g "$RESOURCE_GROUP" &>/dev/null; then
  az identity federated-credential create \
    --name "github-$BRANCH" \
    --identity-name "$IDENTITY" \
    --resource-group "$RESOURCE_GROUP" \
    --issuer "https://token.actions.githubusercontent.com" \
    --subject "repo:${REPO}:ref:refs/heads/${BRANCH}" \
    --audiences "api://AzureADTokenExchange"
else
  echo "  déjà présente."
fi

echo "== 3. Droit de déployer, limité au groupe de recette =="
# Contributeur sur le SEUL groupe alterneo-recette : l'identité ne peut
# rien faire ailleurs dans la souscription.
RG_ID=$(az group show -n "$RESOURCE_GROUP" --query id -o tsv)
# Une petite attente : le principal de l'identité met quelques secondes à
# être connu du système de droits juste après sa création.
sleep 20
az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "$RG_ID" \
  -o table 2>/dev/null || echo "  (déjà attribué, ou à relancer si 'principal not found')"

echo
echo "========================================================================"
echo "À ranger dans les secrets GitHub (ce ne sont pas des mots de passe,"
echo "juste des identifiants — l'OIDC n'a pas de secret) :"
echo
echo "AZURE_CLIENT_ID        = $CLIENT_ID"
echo "AZURE_TENANT_ID        = $TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID  = $SUBSCRIPTION_ID"
echo "========================================================================"
