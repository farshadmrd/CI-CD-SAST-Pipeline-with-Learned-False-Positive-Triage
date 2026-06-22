# CI/CD SAST Pipeline with Learned False-Positive Triage

A thesis project that builds a CI/CD pipeline around **Static Application Security
Testing (SAST)** tools and layers a **machine-learned triage step** on top of their
output. SAST tools are notoriously noisy — a large fraction of their warnings are
false positives. The goal of this project is to run multiple analyzers inside a
reproducible CI pipeline and train a model that learns to separate likely-real
findings from likely-false-positives, so reviewers spend their time on what matters.

This repository currently holds the **infrastructure layer**: the Docker images and
Compose setup that provide a Jenkins CI server and the containerized SAST analyzers
it drives.

## Architecture

```
                          ┌──────────────────────────┐
                          │      Jenkins (CI)         │
                          │   Dockerfile.jenkins      │
                          │   + docker CLI            │
                          └────────────┬─────────────┘
                                       │ docker.sock (per-build containers)
                 ┌─────────────────────┼─────────────────────┐
                 ▼                                           ▼
       ┌───────────────────┐                       ┌───────────────────┐
       │   infer-agent     │                       │  cppcheck-agent   │
       │  Dockerfile.agent │                       │ cppcheck-agent.   │
       │  Facebook Infer   │                       │ Dockerfile        │
       └───────────────────┘                       └───────────────────┘
                 │                                           │
                 └──────────────► SAST findings ◄────────────┘
                                       │
                                       ▼
                          (planned) learned FP-triage model
```

Jenkins runs as a long-lived service. The analyzer images are **built but not run**
as services — Jenkins launches them on demand for each build via the Docker Pipeline
plugin, using the host Docker daemon mounted at `/var/run/docker.sock`.

## Components

| File | Image | Role |
|------|-------|------|
| [Dockerfile.jenkins](Dockerfile.jenkins) | `jenkins-docker:lts-jdk17` | Jenkins LTS (JDK 17) with the Docker CLI added so pipelines can launch agent containers. |
| [Dockerfile.agent](Dockerfile.agent) | `infer-agent:1.2.0` | Ubuntu 22.04 + C/C++ build toolchain + [Facebook Infer](https://fbinfer.com/) v1.2.0. |
| [cppcheck-agent.Dockerfile](cppcheck-agent.Dockerfile) | `cppcheck-agent:2.13.0` | Ubuntu 24.04 + [cppcheck](https://cppcheck.sourceforge.io/) + [bear](https://github.com/rizsotto/Bear) + build toolchain. |
| [docker-compose.yml](docker-compose.yml) | — | Orchestrates the Jenkins service and builds the analyzer images. |

### Why `bear`?

`bear` captures a `compile_commands.json` while the target project builds, so cppcheck
analyzes the code with the **same include paths and macro definitions the real build
uses**. This gives cppcheck analysis parity with Infer, which also relies on the
project's actual build.

## Prerequisites

- Docker Engine
- Docker Compose v2 (`docker compose`)
- A Linux host (the setup mounts the host Docker socket)

## Setup

### 1. Match the Docker group ID

Jenkins needs permission to talk to the mounted Docker socket. Find your host's
Docker group ID:

```bash
stat -c '%g' /var/run/docker.sock
```

Then set that value in [docker-compose.yml](docker-compose.yml) under the Jenkins
service's `group_add:` (currently `984`).

### 2. Build the analyzer images

The analyzer agents live behind the `build-only` profile so they are **built** into
the host daemon but never started as services:

```bash
docker compose --profile build-only build
```

This produces `infer-agent:1.2.0` and `cppcheck-agent:2.13.0` locally — the tags the
Jenkins pipeline expects.

### 3. Start Jenkins

```bash
docker compose up -d --build
```

Jenkins is then available at **http://localhost:8080** (agent port `50000`). Its home
directory is persisted in the `jenkins_home` Docker volume.

To retrieve the initial admin password:

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

## Usage

Once Jenkins is up, configure a pipeline job that, per build, runs the analyzer images
against the target C/C++ project — for example capturing the compile database with
`bear` and running `cppcheck`, and running `infer` over the same build. The resulting
SAST findings are the input to the learned false-positive triage stage.

## Roadmap

- [x] Jenkins CI image with Docker CLI
- [x] Infer analyzer agent image
- [x] cppcheck analyzer agent image (with `bear` for build parity)
- [ ] Jenkinsfile defining the analysis pipeline
- [ ] Findings collection / normalization across tools
- [ ] Labeled dataset of true vs. false positives
- [ ] Learned false-positive triage model and its integration into the pipeline

## License

See repository for license details.
