# Alterneo

Plate-forme de pilotage des projets de l'entreprise et de suivi des ingénieurs
apprentis. Projet de Synthèse SIGL 2026/2027 — ESEO.

Architecture microservices : six services Spring Boot derrière une passerelle
d'API, un client React, communication asynchrone par courtier de messages,
déploiement sur Microsoft Azure.

---

## Démarrer en local

Prérequis : Docker et Docker Compose. Rien d'autre — ni Java ni Maven ne sont
nécessaires pour lancer la plate-forme, tout se construit dans les conteneurs.

```bash
git clone https://github.com/lovelace-sigl/alterneo.git
cd alterneo
cp .env.example .env        # puis remplace les « a_changer »
docker compose up --build
```

`cp .env.example .env` n'est pas optionnel : `docker compose` s'arrête avec un
message explicite si les mots de passe sont absents.

Vérifier que tout répond :

```bash
# le microservice
curl http://localhost:8081/api/apprentis/ping
# {"service":"apprentis","statut":"en ligne","horodatage":"..."}

# les cinq bases
docker compose exec postgres psql -U alterneo_admin -d postgres -c '\l'

# le realm Keycloak
curl -s http://localhost:8180/realms/alterneo/.well-known/openid-configuration | head -c 200
```

Arrêter : `docker compose down`. Les données des bases sont conservées.

---

## L'environnement local

| Conteneur | Port | Rôle |
|---|---|---|
| `postgres` | 5432 | serveur de bases partagé — une base et un compte par service (ADR-002) |
| `keycloak` | 8180 | serveur d'identité ; console d'administration sur `http://localhost:8180` |
| `apprentis` | 8081 | microservice Apprentis et alternance |

### Les cinq bases

Créées au premier démarrage par `infra/postgres/init.sh` :

| Base | Compte | Service | Arrive au |
|---|---|---|---|
| `apprentis_db` | `apprentis` | Apprentis et alternance | Sprint 1 |
| `keycloak_db` | `keycloak` | Keycloak (recette et production) | Sprint 1 |
| `projets_db` | `projets` | Projets | Sprint 2 |
| `ressources_db` | `ressources` | Ressources et architecture | Sprint 3 |
| `appreciations_db` | `appreciations` | Appréciations | Sprint 3 |

Chaque compte ne voit que sa propre base : si un service est compromis, il
n'atteint pas les données des autres. Réunions et documents, ainsi que
Notifications, utilisent MongoDB et n'apparaissent donc pas ici.

### ⚠️ Le piège à connaître

PostgreSQL n'exécute `infra/postgres/init.sh` **qu'une seule fois**, au premier
démarrage, quand le volume de données est vide. Si quelqu'un modifie ce script
par la suite, rien ne se passera au redémarrage. Pour qu'il rejoue :

```bash
docker compose down -v      # le -v efface le volume, donc toutes les données locales
docker compose up
```

C'est la cause numéro un des « ça marche chez moi mais pas chez toi » sur ce
genre de montage. En cas de doute sur l'état de ta base, `down -v` puis `up`
remet tout à plat en une minute.

---

## Brancher un service sur sa base

Le `docker-compose.yml` injecte déjà les trois variables que Spring Boot
attend. **Rien à ajouter dans `application.yml`** : il suffit de mettre JPA et
le pilote PostgreSQL sur le classpath, dans le `pom.xml` du service.

```xml
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-data-jpa</artifactId>
</dependency>
<dependency>
  <groupId>org.postgresql</groupId>
  <artifactId>postgresql</artifactId>
  <scope>runtime</scope>
</dependency>
```

Spring Boot lit alors `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME` et
`SPRING_DATASOURCE_PASSWORD`, fournies par le conteneur.

**Deux conséquences à traiter dans la même pull request :**

1. **Les tests.** Dès que JPA est sur le classpath, un test qui charge le
   contexte Spring cherche une base de données — et il n'y en a pas dans le
   runner GitHub. Sans précaution, la chaîne d'intégration passe au rouge. La
   solution la plus simple est H2 en portée test, avec un
   `src/test/resources/application-test.yml` qui le configure ; Testcontainers
   est plus fidèle mais plus lourd. À arbitrer avec la stratégie de tests
   (rubrique 4.1).
2. **Le déploiement de recette.** L'environnement Azure n'a pas encore de base
   de données. Un service qui en exige une ne démarrera pas là-bas. Tant que
   la base de recette n'est pas tranchée, garder le démarrage possible sans
   base, ou accepter que la story ne se démontre qu'en local.

### Se connecter à la base à la main

```bash
docker compose exec postgres psql -U apprentis -d apprentis_db
```

Ou depuis un client graphique : `localhost:5432`, base `apprentis_db`,
utilisateur `apprentis`, mot de passe = `SERVICE_DB_PASSWORD` de ton `.env`.

---

## Modifier la configuration Keycloak

Le realm est **réimporté depuis le fichier à chaque démarrage** du conteneur.
`infra/keycloak/realm-alterneo.json` est donc la seule source de vérité : la
configuration ne peut pas dériver d'une machine à l'autre.

Conséquence directe : **une modification faite dans la console
d'administration est perdue au prochain `docker compose up`.** Pour qu'un
changement soit durable et partagé, il doit finir dans le fichier.

Le circuit :

```bash
# 1. ouvrir http://localhost:8180, se connecter avec KEYCLOAK_ADMIN
# 2. modifier ce qu'il faut dans le realm « alterneo »
# 3. exporter le realm modifié
docker compose exec keycloak /opt/keycloak/bin/kc.sh export \
  --dir /tmp/export --realm alterneo --users realm_file
docker compose cp keycloak:/tmp/export/alterneo-realm.json \
  infra/keycloak/realm-alterneo.json
# 4. relire le diff, commiter
```

L'export est verbeux : relire le diff avant de commiter évite d'embarquer des
identifiants techniques générés à chaque démarrage.

Ce que contient le fichier aujourd'hui : le realm `alterneo` et le client
public `alterneo-front` (Authorization Code + PKCE), nécessaires à la
connexion et à la passerelle. Les rôles, les groupes et les utilisateurs sont
vides : ils relèvent de la matrice des droits (rubrique 2.6).

---

## Structure du dépôt

```
alterneo/
├─ .github/workflows/     chaînes d'intégration et de déploiement continus
├─ services/              un dossier par microservice
│  └─ apprentis/          dossier de l'apprenti, école, calendrier d'alternance
├─ client/                application React (TypeScript, Vite)
├─ infra/
│  ├─ postgres/init.sh    création des cinq bases et des cinq comptes
│  ├─ keycloak/           realm versionné
│  └─ azure/              provisionnement de la recette et connexion OIDC
├─ docs/                  décisions d'architecture et dossier de spécification
├─ docker-compose.yml     environnement de développement local
└─ pom.xml                pom parent : versions de Java et de Spring Boot
```

Chaque service possède son propre `pom.xml` et son propre `Dockerfile`, et se
déploie indépendamment des autres. Le pom parent ne sert qu'à centraliser les
versions.

### Les six microservices

| Service | Port | Responsabilité |
|---|---|---|
| Apprentis et alternance | 8081 | dossier de l'apprenti, école, calendrier, examens |
| Projets | 8082 | projets, équipes, tâches, jalons, affectations |
| Ressources et architecture | 8083 | architecture, ressources mobilisées, dépôts liés |
| Réunions et documents | 8084 | créneaux communs, comptes rendus, documents |
| Appréciations | 8085 | grille de compétences, fiches de synthèse |
| Notifications | 8086 | alertes dans la plate-forme et par courriel |

La passerelle d'API écoute sur 8080 et constitue le seul point d'entrée.
Keycloak, le serveur d'identité, écoute sur 8180.

---

## Travailler sur un service sans Docker

L'infrastructure reste dans Docker, le service tourne sur ta machine :

```bash
docker compose up -d postgres keycloak
cd services/apprentis
mvn spring-boot:run
```

Attention : hors conteneur, l'hôte de la base n'est plus `postgres` mais
`localhost`. Surcharge l'URL au lancement :

```bash
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/apprentis_db \
SPRING_DATASOURCE_USERNAME=apprentis \
SPRING_DATASOURCE_PASSWORD=... \
mvn spring-boot:run
```

Lancer les tests d'un service, depuis la racine :

```bash
mvn -pl services/apprentis -am test
```

---

## Déploiement

| Environnement | Déclenchement | Où |
|---|---|---|
| Développement | `docker compose up` | ta machine |
| Recette | automatique à chaque fusion sur `main` | Azure Container Apps |
| Production | manuel, sur étiquette `v*` | à venir |

L'intégration continue tourne à chaque pull request : compilation, tests et
analyse SonarQube Cloud. Le déploiement continu ne tourne **que** sur `main` —
jamais sur une branche de fonctionnalité. Pour le suivre :

```bash
gh run list --repo lovelace-sigl/alterneo --limit 10
gh run watch <id>
gh run view <id> --log-failed
```

Un workflow au vert ne garantit pas un service vivant : si l'image est
déployée mais que l'application plante au démarrage, Azure conserve l'ancienne
révision active. Pour voir ce qui se passe dans le conteneur :

```bash
az containerapp logs show --name apprentis -g alterneo-recette --follow
az containerapp revision list --name apprentis -g alterneo-recette -o table
```

Le provisionnement de la recette est dans `infra/azure/` :
`provision.sh` crée les ressources, `setup-oidc.sh` établit la connexion sans
secret entre GitHub Actions et Azure.

---

## Contribuer

La branche `main` est protégée : toute modification passe par une pull request
relue et approuvée, avec une chaîne d'intégration au vert.

```bash
git checkout main && git pull origin main
git checkout -b feature/42-description-courte
# ... travailler ...
git commit -m "feat(apprentis): décrit le changement à l'impératif"
git push -u origin feature/42-description-courte
```

Le détail des conventions — nommage des branches, types de commit, règles de
pull request, releases — est dans `docs/CONVENTIONS_GIT.md`.

**Le dépôt est public : aucun secret ne doit y être commité.** Les valeurs
locales vont dans `.env`, qui est ignoré par git ; les secrets de recette et de
production vivent dans les GitHub Secrets et dans Azure Key Vault.

---

## Équipe

| Membre | Rôle Scrum | Périmètre |
|---|---|---|
| Yvana Ngondi | Proxy Product Owner | Apprentis et alternance |
| Jenny Tchiegue | Administratrice système | Projets, administration Keycloak |
| Zeineb | Scrum Master | Réunions, Appréciations, Ressources |
| Davis Tchedjou Pokam | Responsable DevOps | Passerelle, CI/CD, Azure |
| Manasse | Responsable UI | Notifications, client React, charte graphique |
