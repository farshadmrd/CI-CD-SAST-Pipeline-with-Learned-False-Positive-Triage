FROM docker:cli AS dockercli
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git \
    && rm -rf /var/lib/apt/lists/*

# docker CLI only, no daemon. Horusec is an orchestrator: it talks to the host
# daemon through the mounted socket and launches one tool container per language
# (Flawfinder for C). The CLI must be present for that to work.
COPY --from=dockercli /usr/local/bin/docker /usr/local/bin/docker

# Pin a release for reproducibility: replace 'latest/download' with 'download/vX.Y.Z'.
RUN curl -fsSL https://github.com/ZupIT/horusec/releases/latest/download/horusec_linux_amd64 \
        -o /usr/local/bin/horusec \
    && chmod +x /usr/local/bin/horusec \
    && horusec version
