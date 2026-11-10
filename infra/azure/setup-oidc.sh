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
ORG="lovelace-sigl"
REPO_NAME="alterneo"
BRANCH="main"

# ---------------------------------------------------------------------------
# Identifiants NUMÉRIQUES de l'organisation et du dépôt.
#
# GitHub n'envoie plus le sujet « lisible » repo:org/depot:ref:... mais un
# sujet IMMUABLE qui contient ces deux nombres :
#
#     repo:<org>@<idOrg>/<depot>@<idDepot>:ref:refs/heads/<branche>
#
# L'intérêt : renommer l'organisation ou le dépôt ne casse pas la
# confiance, et personne ne peut récupérer un nom libéré pour se faire
# passer pour nous. Le prix : une credential écrite à l'ancienne format
# échoue avec « AADSTS700213 : No matching federated identity record found ».
#
# Pour relever ces valeurs :
#     gh api /orgs/lovelace-sigl --jq .id
#     gh api /repos/lovelace-sigl/alterneo --jq .id
# ---------------------------------------------------------------------------
ORG_ID="342917900"
REPO_ID="1420727469"

SUBJECT="repo:${ORG}@${ORG_ID}/${REPO_NAME}@${REPO_ID}:ref:refs/heads/${BRANCH}"

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

echo "== 2. Credential fédérée =="
echo "  sujet attendu : $SUBJECT"
SUJET_ACTUEL=$(az identity federated-credential show \
                 --name "github-$BRANCH" --identity-name "$IDENTITY" \
                 -g "$RESOURCE_GROUP" --query subject -o tsv 2>/dev/null || true)

if [ -z "$SUJET_ACTUEL" ]; then
  echo "  création"
  az identity federated-credential create \
    --name "github-$BRANCH" \
    --identity-name "$IDENTITY" \
    --resource-group "$RESOURCE_GROUP" \
    --issuer "https://token.actions.githubusercontent.com" \
    --subject "$SUBJECT" \
    --audiences "api://AzureADTokenExchange" \
    -o none
elif [ "$SUJET_ACTUEL" != "$SUBJECT" ]; then
  echo "  correction du sujet (était : $SUJET_ACTUEL)"
  az identity federated-credential update \
    --name "github-$BRANCH" \
    --identity-name "$IDENTITY" \
    --resource-group "$RESOURCE_GROUP" \
    --issuer "https://token.actions.githubusercontent.com" \
    --subject "$SUBJECT" \
    --audiences "api://AzureADTokenExchange" \
    -o none
else
  echo "  déjà correcte."
fi

echo "== 3. Droit de déployer, limité au groupe de recette =="
# Contributeur sur le SEUL groupe alterneo-recette : l'identité ne peut
# rien faire ailleurs dans la souscription.
RG_ID=$(az group show -n "$RESOURCE_GROUP" --query id -o tsv)

# On teste la présence du droit AVANT de l'attribuer, au lieu de masquer
# l'erreur d'un « || echo ». Masquer l'erreur fait croire que tout va bien
# alors que le déploiement échouera plus tard en « AuthorizationFailed ».
DROIT=$(az role assignment list \
          --assignee "$PRINCIPAL_ID" \
          --scope "$RG_ID" \
          --role "Contributor" \
          --query "[0].id" -o tsv 2>/dev/null || true)

if [ -n "$DROIT" ]; then
  echo "  déjà attribué."
else
  # Le principal de l'identité met quelques secondes à être connu du
  # système de droits juste après sa création : on réessaie.
  for tentative in 1 2 3 4 5; do
    if az role assignment create \
         --assignee-object-id "$PRINCIPAL_ID" \
         --assignee-principal-type ServicePrincipal \
         --role "Contributor" \
         --scope "$RG_ID" \
         -o none; then
      echo "  attribué."
      break
    fi
    if [ "$tentative" = 5 ]; then
      echo "  ÉCHEC après 5 tentatives. Le déploiement échouera en"
      echo "  AuthorizationFailed : relance ce script dans une minute."
      exit 1
    fi
    echo "  tentative $tentative échouée (principal pas encore propagé), nouvelle tentative dans 15 s"
    sleep 15
  done
fi

echo
echo "========================================================================"
echo "À ranger dans les secrets GitHub (ce ne sont pas des mots de passe,"
echo "juste des identifiants — l'OIDC n'a pas de secret) :"
echo
echo "AZURE_CLIENT_ID        = $CLIENT_ID"
echo "AZURE_TENANT_ID        = $TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID  = $SUBSCRIPTION_ID"
echo "========================================================================"
