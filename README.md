# docker-alerta

Orchestration repo for Alerta: it holds **DEPENDENCIES** (pinned subproject versions), TeamCity Kotlin DSL under **.teamcity/**, and scripts TeamCity runs from **scripts/**.

---

## Full release flow: subprojects, then docker-alerta

Use this order when you have pushed changes to the component repos and want a coordinated **Docker-alerta** release. The subprojects wired in TeamCity are **lucera-alerta**, **lucera-alerta-ui**, and **lucera-alerta-plugins** (see **.teamcity/Configuration.kt**).

**At a glance:** For every component repo you touched, **push → TeamCity Build → TeamCity Release**. Each successful subproject **Release** automatically starts **Docker-alerta → Dependency Version Update**, which bumps **DEPENDENCIES** and pushes to this repo. When those jobs have finished and the pins look correct, switch to the **Docker-alerta** project in TeamCity and run **Build**, then **Release** — you do **not** skip straight to **Release** on docker-alerta without a green **Build** on the branch you are releasing.

### 1. Per subproject (repeat for each repo you changed)

For **lucera-alerta**, **lucera-alerta-ui**, and/or **lucera-alerta-plugins**:

1. Push your commits to the branch TeamCity watches (for example `main` or `release*`).
2. Run **Build** on that subproject in TeamCity (validates the commit).
3. Run **Release** on that subproject (cuts the component release and exposes version parameters TeamCity needs next).

You only need to Build and Release the repos that actually changed. If all three changed, run Build → Release for each, in any order that fits your process (each **Release** is independent until docker-alerta).

### 2. docker-alerta picks up new versions (mostly automatic)

When any subproject **Release** completes successfully, TeamCity starts **Docker-alerta → Dependency Version Update** for that component. You normally **do not** start that build by hand; finish-build triggers pass `SERVICE_NAME`, `SERVICE_VERSION`, and `SERVICE_BRANCH` from the subproject **Release** into `dependencyUpdate.sh`. That job updates the matching line in **DEPENDENCIES** and **commits and pushes** to docker-alerta. If several subprojects release close together, you may see several Dependency Version Update runs; let them finish so **DEPENDENCIES** on the default or `release*` branch matches what you intend before you cut the docker-alerta **Release**.

### 3. docker-alerta: Build, then Release

**After** lucera-alerta / lucera-alerta-ui / lucera-alerta-plugins are built and released as needed, **yes — you then use the Docker-alerta project in TeamCity**: first **Build**, then **Release**. That is how the orchestration repo gets a proper release tag and release metadata on top of the **DEPENDENCIES** lines the dependency job already pushed.

1. **Pull or wait for git** — Confirm docker-alerta’s branch has the **DEPENDENCIES** updates you expect (TeamCity may have pushed them).
2. Run **Docker-alerta → Build** — Same idea as the subprojects: validates `./scripts/build.sh` and `./scripts/test.sh` on the current tree, including the updated pins.
3. Run **Docker-alerta → Release** — The Release configuration **depends on Build**, so Build must have succeeded on the branch you release from (TeamCity’s snapshot dependency enforces this). Release runs `checkoutAndTagReleaseProject` and writes **tags / release metadata** for docker-alerta itself.

**Summary:** subproject push → **Build** → **Release** (per changed repo) → **Dependency Version Update** updates docker-alerta’s **DEPENDENCIES** → on docker-alerta, **Build** then **Release** to publish the orchestration release.

---

## docker-alerta-only (quick reference)

If you only changed **this** repo (no new subproject releases):

1. Push → **Build** → **Release** on Docker-alerta (Release still requires a successful Build snapshot on your release branch).

**Dependency Version Update** is for when a subproject **Release** finishes; it is not the step you run for “I only edited scripts or docs in docker-alerta.”

---

## What lives where

| Path | Role |
|------|------|
| **DEPENDENCIES** | One line per subproject: `name: version` (underscores in names, e.g. `lucera_alerta: v0.1.1`). Updated by **Dependency Version Update**, not by syncing `metadata.hcl`. |
| **scripts/** | Shell scripts TeamCity runs from the repo root; keep them executable (`chmod +x scripts/*.sh`). |
| **.teamcity/** | Kotlin DSL: `Configuration.kt` for org, repos, and lists; `settings.kts` wires VCS and projects. |

Optional **packs/alerta_release/** may exist for Nomad; **metadata.hcl** is not auto-updated from **DEPENDENCIES**.

---

## TeamCity setup (quick reference)

- **Generate DSL** from the directory that contains `.teamcity` / `pom.xml`:

  ```bash
  mvn org.jetbrains.teamcity:teamcity-configs-maven-plugin:generate
  ```

- **Parameters** scripts expect (set in TeamCity or DSL): `GITHUB_TOKEN`, `GITHUB_ORG`, `REPO_PREFIX`, `RELEASE_REPO_NAME`, `GIT_EMAIL`, `GIT_USERNAME`.

- **Subprojects** have their own **Build** and **Release** in TeamCity; their **Release** completion triggers docker-alerta **Dependency Version Update**.

- Adjust **.teamcity/Configuration.kt** for your GitHub org and repository names before relying on production builds.
