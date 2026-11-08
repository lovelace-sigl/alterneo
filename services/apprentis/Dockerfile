# ---------------------------------------------------------------------------
# Service Apprentis et alternance — image multi-étapes
#
# ATTENTION au contexte de construction : ce Dockerfile a besoin du pom
# parent, qui est à la RACINE du dépôt. Il se construit donc depuis la
# racine, pas depuis ce dossier :
#
#   docker build -f services/apprentis/Dockerfile -t alterneo/apprentis .
#
# C'est ce que fait docker-compose.yml (context: . / dockerfile: ...).
# ---------------------------------------------------------------------------

# --- Étape 1 : compilation -------------------------------------------------
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build

# Les poms d'abord, seuls : tant qu'ils ne changent pas, Docker réutilise
# le cache des dépendances et la construction reste rapide.
COPY pom.xml .
COPY services/apprentis/pom.xml services/apprentis/
RUN mvn -q -pl services/apprentis -am dependency:go-offline

# Puis le code source.
COPY services/apprentis/src services/apprentis/src
# Les tests ne sont pas rejoués ici : la chaîne d'intégration continue les a
# déjà exécutés sur la pull request. Construire l'image deux fois plus vite.
RUN mvn -q -pl services/apprentis -am package -DskipTests

# --- Étape 2 : exécution ---------------------------------------------------
# Image sans Maven ni JDK : plus légère et moins exposée.
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

COPY --from=build /build/services/apprentis/target/*.jar app.jar

EXPOSE 8081
# Utilisateur non root.
USER 1000

ENTRYPOINT ["java", "-jar", "app.jar"]
