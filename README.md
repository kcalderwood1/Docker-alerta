# docker-alerta

## 1. What this repo does

**docker-alerta** is the **orchestration/release** repo. It:

- Keeps a **DEPENDENCIES** file that lists subproject names and their **release versions** (single source of truth).
- Subprojects are **normal repos** (not nomad-packs): they have releases built in TeamCity; when they release, docker-alerta's **DEPENDENCIES** file is updated with the new version.
- Optionally it can still define a nomad-pack under `packs/alerta_release/` (e.g. for deployment); **metadata.hcl is not kept in sync** only DEPENDENCIES is updated by the pipeline.

TeamCity runs the scripts in this repo (and in subproject repos) to build, release, and update **DEPENDENCIES**.

---

## 2. Main setup points

### A. Repos and structure

- Subproject repos (e.g. **lucera-alerta**, **lucera-alerta-ui**, **lucera-alerta-plugins**) produce releases that get recorded in docker-alerta's DEPENDENCIES.
- In this repo you need:
  - **scripts/** — All `.sh` scripts run by TeamCity.
  - **DEPENDENCIES** — One line per subproject: `name: version` (e.g. `lucera_alerta: v0.1.1`). Names should use **underscores** and match the normalized subproject name TeamCity passes as `SERVICE_NAME` (repo name with `-` → `_`).
  - **.teamcity/** — Kotlin DSL that defines the TeamCity project and build configs.
  - Optionally **packs/alerta_release/** if you still use a nomad-pack; it is **not** updated from DEPENDENCIES.

### B. TeamCity config (Kotlin DSL)

- **Single source of truth:** **.teamcity/Configuration.kt** — GitHub org, token param name, VCS URLs, git identity, Docker build image, release repo name, subprojects list, deployments.
- **settings.kts** — Root project: VCS roots for subprojects and Docker-alerta (branches + tags), creates subprojects and the "Alerta release" project from config.
- **Projects:** Subproject builds (e.g. AlertaShellProject: build + release), Docker-alerta project (build, release, dependency update, prepare release), and deployments (e.g. AlertaDeploymentProject).
- **Generate config:** Run the TeamCity configs Maven plugin so TeamCity sees the Kotlin DSL:

  ```bash
  mvn org.jetbrains.teamcity:teamcity-configs-maven-plugin:generate
  ```

  (from the repo root that contains `.teamcity` / `pom.xml`).

### C. Credentials and parameters

- **GitHub:** A personal access token (or bot token) with repo access. Stored in TeamCity as a password parameter (e.g. `MY_GITHUB_TOKEN`); scripts receive it as `env.GITHUB_TOKEN`.
- **Config in TeamCity:** Scripts expect (set in TeamCity or in `settings.kts`):
  - `env.GITHUB_TOKEN`
  - `env.GITHUB_ORG`
  - `env.REPO_PREFIX` (e.g. `https://github.com/org/`)
  - `env.RELEASE_REPO_NAME` (e.g. `Docker-alerta`)
  - `env.GIT_EMAIL`, `env.GIT_USERNAME` for commits.

### D. Scripts and permissions

- All **scripts/*.sh** must be executable (e.g. `chmod +x scripts/*.sh`; Git should record 100755).
- TeamCity runs them from the **repo root** (e.g. `./scripts/build.sh`).

### E. DEPENDENCIES only (no metadata.hcl sync)

- **DEPENDENCIES** is the only file updated by the pipeline for dependency versions. Format: one line per subproject, `name: version` (e.g. `lucera_alerta: v0.1.1`). Names must match the **normalized** subproject name (underscores) that TeamCity sends when triggering the Dependency Version Update.
- **metadata.hcl** (if present under `packs/alerta_release/`) is **not** updated from DEPENDENCIES; it can be maintained manually or left static.
- **updateVersion.sh** — Updates **only** DEPENDENCIES for a given service and version.
- **synchronizeVersions.sh** — Only **reports** the contents of DEPENDENCIES (no writing to metadata.hcl, no git operations).

---

## 3. How it runs in TeamCity (flow)

### Subproject (e.g. lucera-alerta-plugins)

- **Build:** VCS trigger → checkout → run `./scripts/build.sh` (and test if present).
- **Release:** On release branch → run release (e.g. `release-it-containerized`) → set `SERVICE_VERSION` / `SERVICE_BRANCH` and publish.

### docker-alerta (this repo)

- **Build:** VCS trigger → checkout → run `./scripts/build.sh` (which runs **synchronizeVersions.sh** to report DEPENDENCIES only; no metadata.hcl sync).
- **Dependency Version Update:** Triggered when a subproject's Release finishes → runs **dependencyUpdate.sh** with `SERVICE_NAME`, `SERVICE_VERSION`, `SERVICE_BRANCH` → checks out docker-alerta and runs **updateVersion.sh** to update **DEPENDENCIES** only → commit and push.
- **Release:** Runs `checkoutAndTagReleaseProject` (tag, update version, create GitHub release with pack archive if used).
- **Prepare Release Branch:** Runs `prepareReleaseBranches` for release branching.

### Deployments

- Separate build type per deployment × environment; uses the tags VCS root of docker-alerta; runs validate/deploy steps (you fill in real deploy logic).

---

## 4. Checklist summary

| Area         | What to do                                                                                                                                   |
|--------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| Repo         | Clone docker-alerta; ensure **scripts/**, **DEPENDENCIES**, **.teamcity/** present.                                                          |
| TeamCity     | Load Kotlin DSL (generate configs); create/attach VCS root(s) for docker-alerta and subprojects as in config.                                |
| Credentials  | Set GitHub token as password param; pass **GITHUB_TOKEN**, **GITHUB_ORG**, **REPO_PREFIX**, **RELEASE_REPO_NAME**, git user/email to builds. |
| Scripts      | Ensure all **scripts/*.sh** are executable (100755) and run from repo root.                                                                  |
| DEPENDENCIES | Only file updated for dependency versions. Keys = normalized subproject names (underscores). metadata.hcl is not synced from DEPENDENCIES.   |
| Config       | In **.teamcity/Configuration.kt** set real **GITHUB_ORG** and repo names (replace any placeholder like "org" in `https://github.com/org/`).  |
