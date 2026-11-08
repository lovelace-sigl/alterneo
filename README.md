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
cp .env.example .env
docker compose up --build
```

Vérifier que le service répond :

```bash
curl http://localhost:8081/api/apprentis/ping
# {"service":"apprentis","statut":"en ligne","horodatage":"..."}

curl http://localhost:8081/actuator/health
# {"status":"UP"}
```

Arrêter : `docker compose down`.

### Travailler sur un service sans Docker

```bash
cd services/apprentis
mvn spring-boot:run
```

Lancer les tests d'un service, depuis la racine :

```bash
mvn -pl services/apprentis -am test
```

---

## Structure du dépôt

```
alterneo/
├─ .github/workflows/     chaînes d'intégration et de déploiement continus
├─ services/              un dossier par microservice
│  └─ apprentis/          dossier de l'apprenti, école, calendrier d'alternance
├─ client/                application React (TypeScript, Vite)
├─ infra/                 scripts d'infrastructure (bases, Keycloak, Azure)
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
