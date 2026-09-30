# Módulo 08 — Flux: Quick Start

> **Contexto**: Os módulos anteriores usaram ArgoCD como ferramenta de GitOps.
> Este módulo usa **Flux v2** para gerenciar a mesma stack — mesmos apps,
> mesmos values files, mesma fonte git (Gitea) — mas com a abordagem
> composicional do Flux: controladores separados, CRDs distintos, CLI-first.
>
> **Reutiliza**: stack do módulo 07 (mario, monitoring, mimir, otel, profiler)
> **Novo**: Flux controllers, GitRepository, HelmRepository, Kustomization CRD, HelmRelease

---

## Fase 0 — Cluster

### 0.1 — Verificar ou recriar o cluster

O `cluster-config.yaml` deste módulo é idêntico ao do módulo 07.
O Flux não precisa de porta extra — não há UI web por padrão.

```bash
kind get clusters
# Esperado: k8s-essentials
```

Se precisar recriar:

```bash
kind delete cluster --name k8s-essentials
kind create cluster --name k8s-essentials --config cluster-config.yaml
kubectl config use-context kind-k8s-essentials
kubectl get nodes
```

---

## Fase 1 — Instalar o Flux

### 1.1 — Instalar a CLI do Flux

```bash
# Linux / macOS (script oficial)
curl -s https://fluxcd.io/install.sh | sudo bash

# macOS (Homebrew)
brew install fluxcd/tap/flux

# Windows (PowerShell — Winget)
winget install FluxCD.Flux

# Verificar versão
flux version --client
# Esperado: flux: v2.x.x
```

### 1.2 — Verificar pré-requisitos

```bash
flux check --pre
# Esperado: ✔ prerequisites checks passed
```

### 1.3 — Instalar os controllers Flux no cluster

> **Por que `flux install` e não `flux bootstrap`?**
> O `flux bootstrap` integra direto com GitHub/GitLab e gerencia a própria
> instalação via git (self-managed). Para clusters locais com Gitea precisamos
> fazer bootstrap em dois passos: primeiro `flux install`, depois criar o
> GitRepository manualmente apontando para o Gitea local.

```bash
flux install \
  --namespace flux-system \
  --components source-controller,kustomize-controller,helm-controller,notification-controller

# Verificar instalação
kubectl -n flux-system get pods
# Esperado: 4 pods Running (source, kustomize, helm, notification controllers)

flux check
# Esperado: ✔ all checks passed
```

---

## Fase 2 — Instalar o Gitea

> **Mesmo Gitea do módulo 07.** Se ele já estiver rodando no cluster,
> pule para a Fase 3.

### 2.1 — Adicionar repo Helm e instalar

```bash
helm repo add gitea-charts https://dl.gitea.com/charts/
helm repo update

helm upgrade --install gitea gitea-charts/gitea \
  --namespace gitea --create-namespace \
  -f install/values-gitea.yaml \
  --wait --timeout 5m
```

### 2.2 — Verificar acesso

Abra: http://localhost:33000

Login: `gitops` / `gitops-secret`

### 2.3 — Criar o repositório no Gitea

```bash
# Linux / macOS
curl -X POST http://localhost:33000/api/v1/user/repos \
  -H "Content-Type: application/json" \
  -u gitops:gitops-secret \
  -d '{"name":"caio-k8s","private":false,"auto_init":false}'
```
```pwsh
# Windows (PowerShell)
$creds = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("gitops:gitops-secret"))
Invoke-RestMethod http://localhost:33000/api/v1/user/repos `
  -Method Post `
  -ContentType "application/json" `
  -Headers @{ Authorization = "Basic $creds" } `
  -Body '{"name":"caio-k8s","private":false,"auto_init":false}'
```

---

## Fase 3 — Push do Repositório para o Gitea

> O Flux vai sincronizar a partir do Gitea interno. Faça push do repositório
> local para lá. Se já fez isso no módulo 07, apenas confirme que está atual.

### 3.1 — Adicionar o Gitea como remote e fazer push

```bash
# Na raiz do repositório caio-k8s
git remote add gitea http://localhost:33000/gitops/caio-k8s.git

# Ou, se o remote já existir, atualize:
git remote set-url gitea http://localhost:33000/gitops/caio-k8s.git

git push gitea main
# Informe usuário: gitops | senha: gitops-secret
```
```pwsh
# Windows: credenciais no comando
git -c http.extraHeader="Authorization: Basic $(
  [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('gitops:gitops-secret'))
)" push gitea main
```

---

## Fase 4 — Registrar GitRepository e Kustomizations Raiz

### 4.1 — Aplicar root-sync.yaml

Este é o único `kubectl apply` manual. Tudo que vem depois é gerenciado
pelo próprio Flux via git.

```bash
kubectl apply -f flux/flux-system/root-sync.yaml
```

> O `root-sync.yaml` contém:
> - `GitRepository caio-k8s`: aponta para o Gitea interno
> - `Kustomization flux-sources`: instala os HelmRepositories (sources/)
> - `Kustomization flux-apps`: instala todos os HelmReleases e Kustomizations (apps/)

### 4.2 — Verificar sincronização das sources

```bash
# Aguardar o GitRepository ficar Ready
kubectl -n flux-system get gitrepository caio-k8s
# Esperado: READY=True, REVISION=main@sha1:...

# Aguardar Kustomization flux-sources
flux get kustomization flux-sources
# Esperado: Applied revision: main@sha1:...

# Listar HelmRepositories criados
kubectl get helmrepositories -n flux-system
# Esperado: prometheus-community, grafana, grafana-community, fluent, minio — Ready=True
```

### 4.3 — Verificar sincronização dos apps

```bash
# Status geral de todas as Kustomizations
flux get kustomizations -A

# Status de todos os HelmReleases
flux get helmreleases -A

# Ver todos os recursos Flux de uma vez
flux get all -A
```

> **Tempo estimado**: 5-10 minutos para todos os HelmReleases ficarem Ready
> (tempo de download dos charts + inicialização dos pods).

### 4.4 — Instalação do AIStor Operator (pré-requisito do MinIO)

O AIStor Operator precisa ser instalado **antes** do HelmRelease do minio
tentar criar o ObjectStore. Execute manualmente (fora do Flux):

```bash
helm repo add minio https://helm.min.io
helm repo update

helm upgrade --install aistor-operator minio/aistor \
  --namespace aistor --create-namespace \
  --wait --timeout 5m
```

Após instalar, force o Flux a reconciliar o minio:
```bash
flux reconcile helmrelease minio -n flux-system
```

---

## Fase 5 — Verificar a Stack Completa

```bash
# Pods em todos os namespaces relevantes
kubectl get pods -n games
kubectl get pods -n monitoring

# Resumo da stack
flux get all -A --status-selector ready=true
```

Acesse:
- **Grafana**: http://localhost:3000 (admin / prom-operator)
- **Mario**: http://localhost:8081
- **Prometheus**: http://localhost:9090
- **Mimir**: http://localhost:9009

---

## Fase 6 — Testar o GitOps Loop

### 6.1 — Alterar replicas do Mario via git

```bash
# Editar o arquivo de deployment
# Linha: replicas: 1  →  replicas: 3
# Arquivo: curso-k8s/modulo-07-argocd/stack/mario/01-deployment-mario.yaml

git add curso-k8s/modulo-07-argocd/stack/mario/01-deployment-mario.yaml
git commit -m "feat: scale mario to 3 replicas"
git push gitea main
```

### 6.2 — Observar o Flux agir

```bash
# Acompanhar eventos em tempo real
flux get kustomization mario --watch

# Ver eventos do controller
kubectl -n flux-system get events --sort-by='.lastTimestamp' | tail -20

# Confirmar replicas atualizadas
kubectl get deployment mario -n games
```

### 6.3 — Testar self-healing

```bash
# Mudar replicas manualmente (fora do git)
kubectl scale deployment mario -n games --replicas=10

# Aguardar o próximo ciclo de reconciliação (até 5 minutos)
# OU forçar imediatamente:
flux reconcile kustomization mario --with-source

# Verificar que voltou ao valor do git (3)
kubectl get deployment mario -n games
```

---

## Fase 7 — Comandos Úteis

### flux CLI — Referência Rápida

```bash
# Status de tudo
flux get all -A

# Forçar reconciliação de uma Kustomization (e sua source)
flux reconcile kustomization <nome> --with-source -n flux-system

# Forçar reconciliação de um HelmRelease
flux reconcile helmrelease <nome> -n flux-system

# Forçar reconciliação do GitRepository
flux reconcile source git caio-k8s -n flux-system

# Ver logs de um controller
flux logs --kind=Kustomization --name=mario -n flux-system
flux logs --kind=HelmRelease --name=prometheus-stack -n flux-system

# Suspender reconciliação (útil para manutenção)
flux suspend kustomization mario
flux resume kustomization mario

# Suspend + resume HelmRelease
flux suspend helmrelease prometheus-stack
flux resume helmrelease prometheus-stack

# Debug valores efetivos de um HelmRelease
flux debug helmrelease prometheus-stack -n flux-system --show-values

# Exportar manifests de uma Kustomization
flux export kustomization mario
flux export helmrelease prometheus-stack

# Ver histórico de eventos Flux
flux events -A

# Uninstall completo do Flux (NÃO faz prune dos apps)
flux uninstall --namespace flux-system
```

### kubectl — Status dos CRDs Flux

```bash
# GitRepositories
kubectl get gitrepositories.source.toolkit.fluxcd.io -A

# HelmRepositories
kubectl get helmrepositories.source.toolkit.fluxcd.io -A

# Kustomizations Flux
kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A

# HelmReleases
kubectl get helmreleases.helm.toolkit.fluxcd.io -A
```

---

## Fase 8 — Troubleshooting

### HelmRelease travado em "install retries exhausted"

```bash
# Ver detalhes do erro
kubectl describe helmrelease prometheus-stack -n flux-system

# Resetar o contador de tentativas
flux reconcile helmrelease prometheus-stack -n flux-system
```

### Kustomization não reconcilia

```bash
# Ver motivo
flux get kustomization mario -n flux-system

# Verificar se GitRepository está Ready
flux get source git caio-k8s -n flux-system

# Verificar logs do controller
kubectl logs -n flux-system deploy/kustomize-controller | tail -50
```

### Source não sincroniza com Gitea

```bash
# Ver detalhes do GitRepository
kubectl describe gitrepository caio-k8s -n flux-system

# Verificar DNS interno (Flux usa o nome interno do serviço Gitea)
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup gitea-http.gitea.svc.cluster.local

# Testar conectividade
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -s http://gitea-http.gitea.svc.cluster.local:3000/gitops/caio-k8s.git/info/refs?service=git-upload-pack
```

### Verificar drift correction manualmente

```bash
# Flux compara o estado atual vs. o estado desejado no git
# Para ver o diff:
flux diff kustomization mario --path ./curso-k8s/modulo-07-argocd/stack/mario
```

---

## Questões de Fixação

1. Qual a diferença entre `Kustomization` do Flux e `Kustomization` do Kustomize?
2. Por que o `flux install` foi usado em vez de `flux bootstrap` neste módulo?
3. O que acontece se você deletar um recurso no cluster que está gerenciado por uma Kustomization com `prune: true`?
4. Como o `dependsOn` entre Kustomizations garante a ordem de deploy? Em que situação ele falha (timeout)?
5. No ArgoCD, `sync-wave: "-1"` garante que o MinIO sobe primeiro. No Flux, qual o equivalente exato usado para o minio?
6. O que é o `configMapGenerator` na `kustomization.yaml` e como ele se conecta ao `valuesFrom` no HelmRelease?
7. Por que o Flux sempre tem drift correction ativo, enquanto no ArgoCD precisa de `selfHeal: true`?
