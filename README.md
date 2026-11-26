# Task API – CI/CD pipeline with Git, Jenkins and Docker

Mini-projet DevOps (3 LIG – ISG Sousse). A very small Flask REST API
("Task API") is the application; the project itself is the **CI/CD
pipeline** built around it.

| Endpoint            | Description            |
|---------------------|------------------------|
| `GET /health`       | `{"status":"UP","version":...}` |
| `GET /api/tasks`    | list tasks             |
| `POST /api/tasks`   | add a task `{"title": "..."}` |

## Project structure

```
app/main.py               Flask application
tests/test_api.py         unit tests (pytest), run inside Docker
Dockerfile                multi-stage: builder -> test -> runtime (PYTHON_VERSION build arg)
scripts/smoke_test.sh     smoke test -> PASSED / FAILED + report file
jenkins/Jenkinsfile.pr        Pipeline 1: Build & Smoke on Pull Request -> dev
jenkins/Jenkinsfile.dev       Pipeline 2: full build on push to dev (parallel 3.11 / 3.12)
jenkins/Jenkinsfile.release   Pipeline 3: versioned build on tag vX.Y.Z + artifacts
jenkins-server/           Jenkins in Docker (with Docker CLI + plugins)
```

## The 3 pipelines

| Pipeline | Trigger | Stages | Artifacts |
|----------|---------|--------|-----------|
| PR       | Pull Request (feature/* → dev) | Checkout → Setup → Build (tests + image, py3.12) → Run (Docker) → Smoke Test → Archive Artifacts → Cleanup | build log, smoke results, pipeline report |
| Dev      | push on `dev` | Checkout → Setup → Build **‖ py3.11 / py3.12** → Run ‖ → Smoke ‖ → Archive → Cleanup | same, for both runtimes |
| Release  | tag `vX.Y.Z` | same as Dev + version check + image tagged `task-api:vX.Y.Z` | + `docker-image.tar.gz`, `source.zip`, `SHA256SUMS.txt` |

Every build archives `reports/pipeline-report.txt`, which lists each stage as
PASSED / FAILED (also on failed builds).

## 1. Run Jenkins locally

Requirements: Docker Desktop (Windows/Mac) or Docker Engine (Linux), Git.

```bash
cd jenkins-server
docker compose up -d --build
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Open http://localhost:8080, paste the password, choose **Install suggested
plugins**, create the admin user.

**GitHub token** (avoids API rate limits): GitHub → Settings → Developer
settings → Personal access tokens → *Tokens (classic)* → scopes `repo`.
In Jenkins: *Manage Jenkins → Credentials → System → Global → Add* →
kind **Username with password** (username = GitHub login, password = token),
ID `github-token`.

## 2. Create the 3 Jenkins jobs

For each job: *New Item → **Multibranch Pipeline***, then
*Branch Sources → Add source → GitHub*, credentials `github-token`,
repository URL `https://github.com/<user>/devops-task-api`.

| Job name | Behaviours (Branch Source) | Build Configuration → Script Path | Extra |
|---|---|---|---|
| `1-PR-build-smoke` | keep only **Discover pull requests from origin** (delete "Discover branches" and "Discover pull requests from forks") | `jenkins/Jenkinsfile.pr` | – |
| `2-dev-full-build` | Discover branches (strategy **All branches**) + add **Filter by name (with wildcards)** → Include `dev` (delete both PR behaviours) | `jenkins/Jenkinsfile.dev` | – |
| `3-release-tag` | delete branch and PR behaviours, add **Discover tags** + Filter by name → Include `v*` | `jenkins/Jenkinsfile.release` | Build strategies → add **Tags** (so new tags build automatically) |

In every job set *Scan Repository Triggers → Periodically if not otherwise
run → 1 minute*. (Jenkins on localhost cannot receive GitHub webhooks, so it
polls GitHub every minute.)

> If a tag does not build by itself, open the job → *Tags* tab → the tag →
> **Build Now**.

## 3. Git workflow

- `main`: protected, only receives merges from `dev` (release).
- `dev`: integration branch, every push runs Pipeline 2.
- `feature/*`: one branch per task, merged into `dev` by Pull Request (runs Pipeline 1).
- Tags `vX.Y.Z` on `main` run Pipeline 3.

```bash
git checkout dev && git pull
git checkout -b feature/my-task
# ...work...
git add . && git commit -m "feat: my task"
git push -u origin feature/my-task
# open a Pull Request feature/my-task -> dev on GitHub, wait for Jenkins, merge

# release
git checkout main && git pull && git merge --no-ff dev -m "release v1.0.0"
git tag -a v1.0.0 -m "Version 1.0.0"
git push origin main --tags
```

Branch protection: GitHub repo → *Settings → Branches → Add rule* → pattern
`main` → *Require a pull request before merging*. (Free accounts: the repo
must be **public** for the rule to be enforced.)

## 4. Demo of a FAILED build (for the presentation)

Make a PR where the app listens on the wrong port, e.g. in `Dockerfile`
change `0.0.0.0:5000` to `0.0.0.0:8000`. Unit tests still pass, but the
**Smoke Test** stage fails → build FAILED, and the archived
`smoke-py3.12.txt` shows which checks failed. Close the PR (don't merge) to
go back to green.

## Run locally without Jenkins

```bash
docker build -t task-api .
docker run -d --name task-api-local -p 5000:5000 task-api
bash scripts/smoke_test.sh task-api-local reports/smoke.txt
docker rm -f task-api-local
```
