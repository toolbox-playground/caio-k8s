#!/usr/bin/env bash
# ============================================================
# Laboratório 100% LOCAL — sem GitHub, sem GHCR.
#
# Substitui as peças do GitHub por equivalentes locais, mantendo o
# MESMO fluxo GitOps:
#
#   GitHub (repos)      → Gitea em container      (http://localhost:3001)
#   GitHub Actions      → Gitea Actions + act_runner (mesma sintaxe de workflow)
#   GHCR                → registry:2 local         (localhost:5001)
#   ArgoCD, Helm, ESO, Envoy, OTel, Prometheus, Tempo → idênticos ao real
#
# Comandos:
#   check            validações offline (helm lint, kubeconform, pytest) — sem cluster
#   up               sobe Gitea + registry + runner + cluster kind + ArgoCD + plataforma
#   pipeline         push do app-repo no Gitea → o WORKFLOW roda no runner (.gitea/workflows)
#   ci               atalho sem runner: testa, builda, publica e atualiza envs/dev no Git
#   promote ENV [TAG]  simula o merge do PR de promoção (staging|prod) e sincroniza
#   sync             força o ArgoCD a reconciliar já (sem esperar os 60s)
#   status           mostra Applications, pods e URLs
#   down             remove cluster, Gitea, runner, registry e o diretório de trabalho
#
# Requisitos: docker, kind, kubectl, helm, git (e bash — no Windows use o Git Bash)
# ============================================================
set -euo pipefail
# Git Bash: só o docker deve manter paths de container (/src, /repo) intactos;
# kind/helm/kubectl (nativos do Windows) continuam com a conversão automática.
docker() { MSYS_NO_PATHCONV=1 command docker "$@"; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${LOCAL_LAB_DIR:-$HOME/gitops-lab-local}"
CLUSTER="gitops-prod"
GITEA_HOST_URL="http://gitops:gitops-secret@localhost:3001"   # do host (git push)
GITEA_CLUSTER_URL="http://gitea:3000/gitops/gitops-repo.git"  # de dentro do cluster (ArgoCD)
IMAGE="localhost:5001/webapp"   # os nós do kind mapeiam localhost:5001 → kind-registry:5000
API="http://localhost:3001/api/v1"
AUTH="gitops:gitops-secret"

need() { command -v "$1" >/dev/null || { echo "❌ '$1' não encontrado"; exit 1; }; }
say()  { echo -e "\n▶ $*"; }
# Volumes do docker precisam de path Windows (C:/...) quando rodando no Git Bash
hostpath() { if command -v cygpath >/dev/null; then cygpath -m "$1"; else echo "$1"; fi; }

run_pytest() {
  docker run --rm -v "$(hostpath "$HERE")/app-repo:/src" -w /src python:3.12-slim \
    sh -c "pip install -q -r requirements-dev.txt 2>&1 | tail -1; python -m pytest -q -p no:cacheprovider"
}

# ── check ───────────────────────────────────────────────────
cmd_check() {
  need helm; need docker
  local schemas="https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json"

  say "helm lint (dev/staging/prod)"
  for e in dev staging prod; do
    helm lint "$HERE/gitops-repo/charts/webapp" -f "$HERE/gitops-repo/envs/$e/values.yaml" | tail -1
  done

  say "kubeconform (schemas do Kubernetes + CRDs)"
  for e in dev staging prod; do
    helm template webapp "$HERE/gitops-repo/charts/webapp" -f "$HERE/gitops-repo/envs/$e/values.yaml" \
      | docker run --rm -i ghcr.io/yannh/kubeconform:latest -strict -summary -ignore-missing-schemas \
          -schema-location default -schema-location "$schemas" -
  done
  docker run --rm -v "$(hostpath "$HERE")/gitops-repo:/repo:ro" ghcr.io/yannh/kubeconform:latest \
    -strict -summary -ignore-missing-schemas -schema-location default -schema-location "$schemas" \
    /repo/bootstrap/00-projects.yaml /repo/bootstrap/01-root.yaml \
    /repo/platform/apps /repo/platform/config /repo/platform/workloads

  say "testes da aplicação (pytest dentro de container)"
  run_pytest
  echo -e "\n✅ check OK"
}

# ── Gitea Actions: runner + repo webapp ─────────────────────
setup_runner() {
  curl -fsS -u "$AUTH" -X POST "$API/user/repos" -H 'Content-Type: application/json' \
    -d '{"name":"webapp","private":false,"default_branch":"main"}' >/dev/null 2>&1 || true
  # Secret lido pelo workflow para escrever no gitops-repo (no real: GitHub App)
  curl -fsS -u "$AUTH" -X PUT "$API/repos/gitops/webapp/actions/secrets/GITOPS_PASSWORD" \
    -H 'Content-Type: application/json' -d '{"data":"gitops-secret"}' >/dev/null

  docker ps --format '{{.Names}}' | grep -qx gitea-runner && return
  docker rm -f gitea-runner >/dev/null 2>&1 || true
  mkdir -p "$WORK/runner"
  cat > "$WORK/runner/config.yaml" <<'YAML'
log:
  level: info
runner:
  capacity: 1
  file: /data/.runner
container:
  network: kind          # os jobs enxergam 'gitea' pelo nome
YAML
  local token
  token="$(docker exec -u git gitea gitea actions generate-runner-token | tr -d '\r\n')"
  docker run -d --name gitea-runner --network kind --restart=unless-stopped \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$(hostpath "$WORK/runner"):/data" \
    -e CONFIG_FILE=/data/config.yaml \
    -e GITEA_INSTANCE_URL=http://gitea:3000 \
    -e GITEA_RUNNER_REGISTRATION_TOKEN="$token" \
    -e GITEA_RUNNER_NAME=local-runner \
    -e GITEA_RUNNER_LABELS="ubuntu-latest:docker://catthehacker/ubuntu:act-22.04" \
    gitea/act_runner:latest >/dev/null
}

# ── up ──────────────────────────────────────────────────────
cmd_up() {
  need docker; need kind; need kubectl; need helm; need git; need curl
  docker info >/dev/null 2>&1 || { echo "❌ Docker não está rodando"; exit 1; }

  say "Gitea (servidor Git + Actions)"
  if ! docker ps -a --format '{{.Names}}' | grep -qx gitea; then
    docker run -d --name gitea -p 3001:3000 \
      -e GITEA__security__INSTALL_LOCK=true \
      -e GITEA__database__DB_TYPE=sqlite3 \
      -e GITEA__server__ROOT_URL=http://gitea:3000/ \
      -e GITEA__actions__ENABLED=true \
      -e GITEA__service__DISABLE_REGISTRATION=true \
      gitea/gitea:1.22 >/dev/null
  else
    docker start gitea >/dev/null
  fi
  for _ in $(seq 60); do curl -fsS http://localhost:3001/api/healthz >/dev/null 2>&1 && break; sleep 2; done
  docker exec -u git gitea gitea admin user create --admin --username gitops --password gitops-secret \
    --email gitops@local.dev --must-change-password=false >/dev/null 2>&1 || true
  curl -fsS -u "$AUTH" -X POST "$API/user/repos" -H 'Content-Type: application/json' \
    -d '{"name":"gitops-repo","private":false,"default_branch":"main"}' >/dev/null 2>&1 || true

  say "cluster kind '$CLUSTER'"
  kind get clusters | grep -qx "$CLUSTER" || kind create cluster --config "$HERE/cluster-config.yaml"
  # Gitea precisa estar na rede do kind para o ArgoCD (dentro do cluster) resolver 'gitea'
  docker network connect kind gitea 2>/dev/null || true

  say "registry local (localhost:5001), acessível pelos nós do kind"
  if ! docker ps -a --format '{{.Names}}' | grep -qx kind-registry; then
    docker run -d --restart=always -p 127.0.0.1:5001:5000 --name kind-registry registry:2 >/dev/null
  else
    docker start kind-registry >/dev/null 2>&1 || true
  fi
  docker network connect kind kind-registry 2>/dev/null || true
  for node in $(kind get nodes --name "$CLUSTER"); do
    docker exec "$node" mkdir -p /etc/containerd/certs.d/localhost:5001
    printf '[host."http://kind-registry:5000"]\n' \
      | docker exec -i "$node" sh -c 'cat > /etc/containerd/certs.d/localhost:5001/hosts.toml'
  done

  say "Gitea Actions: runner + repo webapp"
  mkdir -p "$WORK"
  setup_runner

  say "gitops-repo local (clone do Gitea + conteúdo do módulo)"
  [[ -d "$WORK/gitops-repo/.git" ]] || git clone -q "$GITEA_HOST_URL/gitops/gitops-repo.git" "$WORK/gitops-repo"
  git -C "$WORK/gitops-repo" checkout -q -B main
  cp -r "$HERE/gitops-repo/." "$WORK/gitops-repo/"
  git -C "$WORK/gitops-repo" config core.autocrlf false
  git -C "$WORK/gitops-repo" config user.name "local-lab"
  git -C "$WORK/gitops-repo" config user.email "local-lab@local.dev"

  say "bootstrap (ArgoCD + root app), mesmo script da produção"
  CREATE_KIND=false AUTO_PUSH=true \
  GITOPS_REPO_URL="$GITEA_CLUSTER_URL" IMAGE_REPOSITORY="$IMAGE" \
  GITOPS_DIR="$WORK/gitops-repo" "$HERE/scripts/bootstrap.sh"

  cat <<EOF

✅ Lab local no ar.
   Gitea    http://localhost:3001   (gitops / gitops-secret)  repos: gitops/gitops-repo, gitops/webapp
   Próximo: ./scripts/local-lab.sh pipeline   (roda o workflow no runner e faz o deploy em dev)
            ./scripts/local-lab.sh ci         (atalho sem runner)
EOF
}

# ── pipeline (Gitea Actions) ────────────────────────────────
cmd_pipeline() {
  need git
  say "publicando app-repo no Gitea (gitops/webapp) → dispara .gitea/workflows/ci-cd.yml"
  [[ -d "$WORK/webapp/.git" ]] || git clone -q "$GITEA_HOST_URL/gitops/webapp.git" "$WORK/webapp"
  git -C "$WORK/webapp" checkout -q -B main
  cp -r "$HERE/app-repo/." "$WORK/webapp/"
  git -C "$WORK/webapp" config core.autocrlf false
  git -C "$WORK/webapp" config user.name "local-lab"
  git -C "$WORK/webapp" config user.email "local-lab@local.dev"
  git -C "$WORK/webapp" add -A
  git -C "$WORK/webapp" commit -qm "feat: webapp $(date +%H%M%S)" --allow-empty
  git -C "$WORK/webapp" push -q origin HEAD:main
  echo "Acompanhe: http://localhost:3001/gitops/webapp/actions   (ou: docker logs -f gitea-runner)"
  echo "Ao terminar, o commit 'chore(dev): deploy webapp ...' aparece em gitops/gitops-repo."
}

set_tag() { # env tag
  sed -i.bak -E "s#^(  tag: ).*#\1\"$2\"#" "$WORK/gitops-repo/envs/$1/values.yaml"
  rm -f "$WORK/gitops-repo/envs/$1/values.yaml.bak"
}

# ── ci (atalho sem runner) ──────────────────────────────────
cmd_ci() {
  need docker; need git
  local tag="sha-$(date +%H%M%S)"

  say "1/4 test";  run_pytest
  say "2/4 build $IMAGE:$tag"; docker build -q -t "$IMAGE:$tag" "$HERE/app-repo"
  say "3/4 push para o registry local (no lugar do GHCR)"; docker push -q "$IMAGE:$tag"
  say "4/4 atualiza envs/dev/values.yaml no Git (é isso que o workflow real faz)"
  git -C "$WORK/gitops-repo" pull -q --rebase origin main
  set_tag dev "$tag"
  git -C "$WORK/gitops-repo" add -A
  git -C "$WORK/gitops-repo" commit -qm "chore(dev): deploy webapp $tag"
  git -C "$WORK/gitops-repo" push -q origin HEAD:main
  echo "$tag" > "$WORK/last-tag"
  cmd_sync
  echo -e "\n✅ Commit publicado; o ArgoCD concilia em até 60s."
  echo "   curl http://webapp.dev.127.0.0.1.nip.io:18088/version   # deve mostrar $tag"
}

cmd_sync() { # força refresh das apps (não espera os 60s)
  for a in webapp-dev webapp-staging webapp-prod; do
    kubectl -n argocd annotate application "$a" argocd.argoproj.io/refresh=hard --overwrite >/dev/null 2>&1 || true
  done
}

# ── promote ─────────────────────────────────────────────────
cmd_promote() {
  local env="${1:?uso: promote <staging|prod> [tag]}"
  git -C "$WORK/gitops-repo" pull -q --rebase origin main
  local tag="${2:-$(sed -n 's/^  tag: "\(.*\)"/\1/p' "$WORK/gitops-repo/envs/dev/values.yaml")}"
  [[ "$env" == "staging" || "$env" == "prod" ]] || { echo "env deve ser staging ou prod"; exit 1; }
  say "promovendo $tag → $env (no real: PR + revisão + merge; aqui: commit direto)"
  set_tag "$env" "$tag"
  git -C "$WORK/gitops-repo" add -A
  git -C "$WORK/gitops-repo" commit -qm "chore($env): promote webapp $tag"
  git -C "$WORK/gitops-repo" push -q origin HEAD:main
  cmd_sync
  if [[ "$env" == "prod" ]]; then
    say "prod não tem auto-sync: este é o 'clique em SYNC' humano"
    sleep 5
    kubectl -n argocd patch application webapp-prod --type merge -p '{"operation":{"sync":{"prune":true,"syncOptions":["CreateNamespace=true","ServerSideApply=true"]}}}'
  fi
}

cmd_status() {
  kubectl -n argocd get applications
  kubectl get pods -A | grep -E "webapp|NAMESPACE" || true
  echo
  echo "ArgoCD  http://localhost:8080  (admin / $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d))"
  echo "Grafana http://localhost:3000  (admin / change-me-in-lab)"
  echo "Gitea   http://localhost:3001  (gitops / gitops-secret)"
}

cmd_down() {
  kind delete cluster --name "$CLUSTER" || true
  docker rm -f gitea gitea-runner kind-registry >/dev/null 2>&1 || true
  rm -rf "$WORK"
  echo "✅ removido"
}

case "${1:-}" in
  check) cmd_check ;;
  up) cmd_up ;;
  pipeline) cmd_pipeline ;;
  ci) cmd_ci ;;
  sync) cmd_sync ;;
  promote) shift; cmd_promote "$@" ;;
  status) cmd_status ;;
  down) cmd_down ;;
  *) sed -n '3,24p' "$0"; exit 1 ;;
esac
