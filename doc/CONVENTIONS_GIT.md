# Conventions git et GitHub — Alterneo

> Page de référence de l'équipe. À reprendre dans Confluence et dans la rubrique 3.7 du dossier.
> **Équipe** : Yvana, Jenny, Zeineb, Davis, Manasse · **Dépôt** : `lovelace-sigl/alterneo`
> **Mise à jour : 2026-10-26**

---

## 1. Le principe : GitHub Flow

Une seule branche durable, `main`, toujours déployable. Chaque story part d'une branche courte, vit le temps d'une pull request, puis disparaît. Pas de branche `develop` : le sujet impose GitHub Flow, et Git Flow nous ferait dévier.

- `main` est **protégée** : aucun commit direct, aucune exception.
- Toute modification passe par une **pull request relue et approuvée** par au moins un autre membre.
- La pull request ne peut être fusionnée que si **GitHub Actions est au vert** : compilation, tests, Quality Gate SonarQube (couverture ≥ 70 %).
- Fusion sur `main` → déploiement automatique sur l'environnement de **recette** Azure.
- Tag `v1.0`, `v2.0`, `v3.0` en fin de sprint → déploiement en **production**.

---

## 2. Nommer sa branche

Une branche par issue, nommée d'après elle. Le numéro en tête permet de retrouver le contexte en un coup d'œil.

```
feature/42-affectation-apprenti
fix/57-taux-superieur-100
docs/88-rubrique-2-4
chore/91-mise-a-jour-dependances
```

Format : `type/<numéro d'issue>-<description-courte-en-minuscules-avec-tirets>`

---

## 3. Le cycle complet, en commandes

### Une seule fois, au départ

```bash
git clone https://github.com/lovelace-sigl/alterneo.git
cd alterneo
```

### Démarrer une story

```bash
git checkout main
git pull origin main                     # partir d'un main à jour
git checkout -b feature/42-affectation-apprenti
```

### Travailler

```bash
git status                               # voir où on en est
git add -p                               # relire ses changements morceau par morceau
git commit -m "feat(projets): positionne un apprenti sur un projet"
```

`git add -p` est préférable à `git add .` : il affiche chaque modification avant de l'ajouter, ce qui évite de commiter un fichier de configuration ou un secret par inadvertance.

### Se remettre à jour avant d'ouvrir la pull request

```bash
git fetch origin
git rebase origin/main
```

En cas de conflit : corriger les fichiers, puis `git add <fichier>` et `git rebase --continue`.

> **Pourquoi `origin/main` et pas `main` ?** `main` est votre copie locale, qui peut dater de plusieurs jours. `origin/main` est ce que le dépôt contient vraiment, rafraîchi par le `git fetch` juste avant. Rebaser sur un `main` périmé revient à rejouer son travail sur une base ancienne et à découvrir les conflits au moment de la pull request.

### Publier

```bash
git push -u origin feature/42-affectation-apprenti   # la première fois
git push --force-with-lease                          # après un rebase, sur SA branche uniquement
```

Puis ouvrir la pull request sur GitHub, avec `Closes #42` dans la description : l'issue se fermera toute seule à la fusion.

### Après la fusion

```bash
git checkout main
git pull origin main
git branch -d feature/42-affectation-apprenti        # ménage local
```

---

## 4. Les types de commit

Format : `type(portée): description à l'impératif`

La **portée** est le microservice ou la zone concernée : `apprentis`, `projets`, `ressources`, `reunions`, `appreciations`, `notifications`, `gateway`, `front`, `infra`. Elle est facultative mais très utile dans un mono-dépôt à six services.

| Type | Quand l'utiliser | Exemple |
|---|---|---|
| `feat` | une nouvelle fonctionnalité | `feat(apprentis): importe le calendrier au format iCal` |
| `fix` | une correction de bug | `fix(projets): refuse un taux total supérieur à 100 %` |
| `docs` | documentation seule (README, OpenAPI, dossier) | `docs(gateway): décrit les routes dans OpenAPI` |
| `style` | mise en forme sans changement de comportement | `style(front): applique le formatage Prettier` |
| `refactor` | réécriture sans changer le comportement | `refactor(appreciations): extrait le calcul de la synthèse` |
| `perf` | amélioration de performance | `perf(projets): ajoute un index sur apprenti_id` |
| `test` | ajout ou correction de tests | `test(apprentis): couvre la règle R1` |
| `build` | build et dépendances (Maven, Dockerfile) | `build(infra): passe le Dockerfile en multi-étapes` |
| `ci` | configuration CI/CD (GitHub Actions, SonarQube) | `ci: bloque la fusion si la Quality Gate échoue` |
| `chore` | tâches diverses (scripts, configuration) | `chore: met à jour le .gitignore` |

Règles d'écriture : description courte, à l'impératif présent (« ajoute », pas « ajouté » ni « ajout »), sans point final, en minuscule après les deux-points.

---

## 5. La pull request

- **Titre** : la même convention que les commits — `feat(apprentis): importe le calendrier d'alternance`
- **Description** : ce qui change, comment le tester, et `Closes #42`
- **Relecture** : au moins une approbation d'un autre membre avant la fusion
- **CI au vert** obligatoire : compilation, tests, Quality Gate SonarQube
- Garder les pull requests **petites** : une story, une PR. Plus c'est gros, moins c'est relu sérieusement.

---

## 6. Les releases

En fin de sprint, une version est étiquetée et publiée. La publication déclenche le déploiement en production sur Azure.

```bash
git checkout main
git pull origin main
git tag -a v1.0 -m "Sprint 1 : passerelle, authentification, service Apprentis, CI/CD"
git push origin v1.0
```

Puis créer la *release* sur GitHub avec ses notes de version.

---

## 7. Ce qu'on ne fait jamais

| Interdit | Pourquoi |
|---|---|
| `git push --force` | Écrase l'historique distant. On utilise `--force-with-lease`, qui refuse si quelqu'un d'autre a poussé entre-temps — et **uniquement sur sa propre branche**, jamais sur `main`. |
| Commiter sur `main` | La branche est protégée ; de toute façon la commande échouerait. |
| Commiter un secret | **Le dépôt est public.** Jamais de clé Azure, de mot de passe de base ni de jeton. Tout passe par les GitHub Secrets et Azure Key Vault. Un secret poussé est considéré comme compromis : il faut le révoquer, pas seulement le supprimer du code. |
| `git commit` sans `-m` ni message | Ouvre un éditeur et finit en message vide ou illisible. |
| Rebaser une branche déjà relue par quelqu'un | Son travail de relecture se perd. Dans ce cas, faire un commit de correction par-dessus. |

---

## 8. Erreurs de syntaxe fréquentes

| À éviter | Correct | Pourquoi |
|---|---|---|
| `git fetch --all & git pull` | `git fetch --all && git pull` | Un seul `&` lance la commande en arrière-plan au lieu d'enchaîner |
| `git push origin/feature/42-x` | `git push origin feature/42-x` | Deux arguments séparés : le dépôt distant, puis la branche |
| `git commit "feat: ..."` | `git commit -m "feat: ..."` | Sans `-m`, git interprète le texte comme un nom de fichier |
| `git rebase main` | `git fetch origin && git rebase origin/main` | Voir l'encadré en section 3 |
| `git branch -avvv` | `git branch -vv` | Deux `v` suffisent pour afficher la branche suivie ; `-a` ajoute les branches distantes |