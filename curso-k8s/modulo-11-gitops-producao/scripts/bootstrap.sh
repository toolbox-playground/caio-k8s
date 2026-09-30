#!/usr/bin/env bash
# ============================================================
# Bootstrap do GitOps — o ÚNICO passo imperativo do módulo.
#
# Depois dele, TODA mudança acontece via Git:
#   cluster ← ArgoCD ← gitops-repo ← (CI do app-repo | PRs de humanos)
#
# Uso:
#   export GITOPS_REPO_URL=https://github.com/minha-org/gitops-repo.git
#   [export GITOPS_REPO_TOKEN=ghp_xxx]   # apenas se o repo for PRIVADO (read-only)
#   [export CREATE_KIND=false]           # em cluster existente (EKS/GKE/AKS/on-prem)
#   [export IMAGE_REPOSITORY=ghcr.io/org/webapp]  # default: derivado da org da URL do repo
#   [export AUTO_PUSH=true]              # commit+push automático dos placeholders (usado pelo modo local)
#   ./scripts/bootstrap.sh
#
# Funciona em Linux, macOS, WSL e Git Bash (Windows).
# Requisitos: kubectl, helm, git (+ kind e docker se CREATE_KIND=true)
# ============================================================
set -euo pipefail

: "${GITOPS_REPO_URL:?Defina GITOPS_REPO_URL (ex.: https://github.com/minha-org/gitops-repo.git)}"
CREATE_KIND="${CREATE_KIND:-true}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-10.9.4}"   # Argo CD v3.5.x
CLUSTER_NAME="gitops-prod"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GITOPS_DIR="${GITOPS_DIR:-$HERE/gitops-repo}"

need() { command -v "$1" >/dev/null || { echo "❌ '$1' não encontrado no PATH"; exit 1; }; }
need kubectl; need helm; need git
[[ "$CREATE_KIND" == "true" ]] && { need kind; need docker; }

# ── 1. Cluster ──────────────────────────────────────────────
if [[ "$CREATE_KIND" == "true" ]]; then
  if kind get clusters | grep -qx "$CLUSTER_NAME"; then
    echo "✔ cluster kind '$CLUSTER_NAME' já existe"
  else
    echo "▶ criando cluster kind '$CLUSTER_NAME'"
    kind create cluster --config "$HERE/cluster-config.yaml"
  fi
fi
kubectl cluster-info >/dev/null

# ── 2. Placeholders: aponta manifests para SEU repositório ──
# repo URL:  https://github.com/<org>/<repo>.git  →  extrai <org> (minúsculo p/ GHCR)
if [[ -z "${IMAGE_REPOSITORY:-}" ]]; then
  ORG="$(echo "$GITOPS_REPO_URL" | sed -E 's#https://github.com/([^/]+)/.*##' | tr '[:upper:]' '[:lower:]')"
  IMAGE_REPOSITORY="ghcr.io/${ORG}/webapp"
fi
if grep -rlq "SEU_ORG" "$GITOPS_DIR" --include='*.yaml' 2>/dev/null; then
  echo "▶ substituindo placeholders SEU_ORG (repo=$GITOPS_REPO_URL, imagem=$IMAGE_REPOSITORY)"
  grep -rl "SEU_ORG" "$GITOPS_DIR" --include='*.yaml' | while read -r f; do
    sed -i.bak       -e "s#https://github.com/SEU_ORG/gitops-repo.git#${GITOPS_REPO_URL}#g"       -e "s#ghcr.io/SEU_ORG/webapp#${IMAGE_REPOSITORY}#g"       "$f" && rm -f "$f.bak"
  done
  if [[ "${AUTO_PUSH:-false}" == "true" ]]; then
    git -C "$GITOPS_DIR" add -A
    git -C "$GITOPS_DIR" commit -qm "chore: configure repo URLs" || true
    git -C "$GITOPS_DIR" push -q origin HEAD:main
  else
    echo "⚠️  Faça commit e push do gitops-repo AGORA — o ArgoCD lê do Git, não do disco:"
    echo "    (cd $GITOPS_DIR && git add -A && git commit -m 'chore: configure repo URLs' && git push)"
    read -r -p "   Pressione ENTER quando o push estiver feito... " _
  fi
fi

# ── 3. ArgoCD ───────────────────────────────────────────────
echo "▶ instalando ArgoCD (chart $ARGOCD_CHART_VERSION)"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --version "$ARGOCD_CHART_VERSION" \
  -f "$GITOPS_DIR/bootstrap/values-argocd.yaml" \
  --wait --timeout 5m

# ── 4. Credencial do repo (somente se privado) ──────────────
if [[ -n "${GITOPS_REPO_TOKEN:-}" ]]; then
  echo "▶ registrando credencial read-only do repositório"
  kubectl -n argocd create secret generic repo-gitops \
    --from-literal=type=git \
    --from-literal=url="$GITOPS_REPO_URL" \
    --from-literal=username=git \
    --from-literal=password="$GITOPS_REPO_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n argocd label secret repo-gitops argocd.argoproj.io/secret-type=repository --overwrite
fi

# ── 5. Projetos + registry OCI + root app ───────────────────
kubectl apply -f "$GITOPS_DIR/bootstrap/00-projects.yaml"
kubectl apply -f "$GITOPS_DIR/bootstrap/02-oci-repo.yaml"
kubectl apply -f "$GITOPS_DIR/bootstrap/01-root.yaml"

PASS="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
cat <<EOF

✅ Bootstrap concluído. O ArgoCD agora está instalando a plataforma sozinho.

   ArgoCD   http://localhost:8080   (admin / $PASS)
   Grafana  http://localhost:3000   (admin / change-me-in-lab)   — após a sync da plataforma
   Apps     http://webapp.dev.127.0.0.1.nip.io:18088/version

   Acompanhe:  kubectl -n argocd get applications -w
EOF
