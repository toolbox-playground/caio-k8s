# Módulo 07 — ArgoCD: Quick Start

> **Contexto**: Os módulos anteriores instalaram a stack manualmente com
> `kubectl apply` e `helm install`. Este módulo faz o mesmo, mas de forma
> **declarativa e automatizada**: você descreve o estado desejado em arquivos
> YAML no git, e o ArgoCD garante que o cluster esteja sempre em sincronia.

---

## Fase 0 — Cluster

### 0.1 — Verificar ou recriar o cluster

O `cluster-config.yaml` deste módulo adiciona dois novos mapeamentos
de porta em relação ao módulo 06:
- **30080 → 8080**: ArgoCD UI
- **33000 → 33000**: Gitea (git server local)

```bash
kind get clusters
# Esperado: k8s-essentials
```

Se precisar recriar (necessário se o cluster foi criado com config anterior):

```bash
kind delete cluster --name k8s-essentials
kind create cluster --name k8s-essentials --config cluster-config.yaml
```

```bash
kubectl config use-context kind-k8s-essentials
kubectl get nodes
```

---

## Fase 1 — Instalar o ArgoCD

### 1.1 — Adicionar o repo Helm

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

### 1.2 — Instalar o ArgoCD

```bash
# Linux / macOS
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  -f install/values-argocd.yaml \
  --wait --timeout 5m
```
```pwsh
# Windows (PowerShell)
helm upgrade --install argocd argo/argo-cd `
  --namespace argocd --create-namespace `
  -f install/values-argocd.yaml `
  --wait --timeout 5m
```

### 1.3 — Obter a senha inicial do admin

```bash
# Linux / macOS
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
# Copie esta senha — será usada no login
```
```pwsh
# Windows (PowerShell)
kubectl -n argocd get secret argocd-initial-admin-secret `
  -o jsonpath="{.data.password}" | ForEach-Object {
    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_))
  }
# Copie esta senha — será usada no login
```

### 1.4 — Acessar a UI

Abra: http://localhost:8080

Login: `admin` / `<senha do passo anterior>`

Você verá o painel vazio do ArgoCD — nenhuma Application ainda.

### 1.5 — (Opcional) Instalar a CLI do ArgoCD

```bash
# Windows (PowerShell)
winget install ArgoProj.ArgoCD

# Ou baixe em: https://github.com/argoproj/argo-cd/releases/latest
```

```bash
# Linux / macOS — login via CLI
argocd login localhost:8080 \
  --username admin \
  --password <senha> \
  --insecure

argocd version
```
```pwsh
# Windows (PowerShell) — login via CLI
argocd login localhost:8080 `
  --username admin `
  --password "<senha>" `
  --insecure

argocd version
```

---

## Fase 2 — Instalar o Gitea (git server local)

> **Por que Gitea e não GitHub?**
> O ArgoCD roda **dentro** do cluster. Para o GitOps loop funcionar
> (push → sync), o ArgoCD precisa acessar o repositório git.
> O Gitea roda dentro do cluster, acessível via DNS interno —
> sem dependência de internet ou conta no GitHub.

### 2.1 — Instalar o Gitea

```bash
helm repo add gitea-charts https://dl.gitea.com/charts/
helm repo update

helm upgrade --install gitea gitea-charts/gitea \
  --namespace gitea --create-namespace \
  -f install/values-gitea.yaml \
  --wait --timeout 5m
```

### 2.2 — Acessar o Gitea

Abra: http://localhost:33000

Login: `gitops` / `gitops-secret`

### 2.3 — Criar o repositório no Gitea

```bash
# Linux / macOS
curl -X POST http://localhost:33000/api/v1/user/repos \
  -H "Content-Type: application/json" \
  -u gitops:gitops-secret \
  -d '{"name":"caio-k8s","private":false,"auto_init":false}'

# Esperado: {"id":1,"name":"caio-k8s",...}
```
```pwsh
# Windows (PowerShell)
$creds = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("gitops:gitops-secret"))
Invoke-RestMethod http://localhost:33000/api/v1/user/repos `
  -Method Post `
  -ContentType "application/json" `
  -Headers @{ Authorization = "Basic $creds" } `
  -Body '{"name":"caio-k8s","private":false,"auto_init":false}'
# Esperado: id, name: caio-k8s, ...
```

### 2.4 — Fazer push dos arquivos do curso para o Gitea

```bash
# Na raiz do workspace (c:\Users\marce\Documents\Toolbox\caio-k8s)
cd c:\Users\marce\Documents\Toolbox\caio-k8s

# Inicializar git se ainda não tiver (ou usar o repo existente)
git init
git add .
git commit -m "feat: módulo 07 - argocd"

# Adicionar o Gitea como remote
git remote add gitea http://gitops:gitops-secret@localhost:33000/gitops/caio-k8s.git

# Push
git push gitea main
# (ou master, dependendo do branch padrão)
```

> **Nota**: O ArgoCD acessa o Gitea via DNS interno `gitea-http.gitea.svc.cluster.local:3000`.
> Você faz push via `localhost:33000` (NodePort). São o mesmo serviço visto de
> lugares diferentes: fora e dentro do cluster.

### 2.5 — Verificar o push no Gitea

Abra: http://localhost:33000/gitops/caio-k8s

Você deve ver os arquivos do curso no Gitea.

---

## Fase 3 — Configurar o Repositório no ArgoCD

O ArgoCD precisa de credenciais para clonar o repositório Gitea
(mesmo sendo público, é boa prática registrar o repo).

### 3.1 — Registrar o repositório

```bash
# Linux / macOS
argocd repo add \
  http://gitea-http.gitea.svc.cluster.local:3000/gitops/caio-k8s.git \
  --username gitops \
  --password gitops-secret \
  --insecure-skip-server-verification
```
```pwsh
# Windows (PowerShell)
argocd repo add `
  http://gitea-http.gitea.svc.cluster.local:3000/gitops/caio-k8s.git `
  --username gitops `
  --password gitops-secret `
  --insecure-skip-server-verification
```

```bash
# Verificar que o repo está acessível
argocd repo list
# Esperado: CONNECTION STATUS = Successful
```

---

## Fase 4 — Criar a App of Apps (raiz)

Esta é a única Application criada manualmente.
Ela aponta para `apps/` e cria todas as outras automaticamente.

### 4.1 — Aplicar a root Application

```bash
kubectl apply -f apps/00-root-app.yaml
```

### 4.2 — Acompanhar a criação das Applications filhas

Na UI do ArgoCD, você verá primeiro a Application `root` aparecer.
Em seguida, o ArgoCD detecta os arquivos `01-mario-app.yaml`...`12-profiler-manifests-app.yaml`
no repositório e cria cada Application filho automaticamente.

```bash
# Linux / macOS
watch argocd app list
# Aguarde todas as Applications aparecerem
```
```pwsh
# Windows (PowerShell) — equivalente ao watch (Ctrl+C para parar)
while ($true) { Clear-Host; argocd app list; Start-Sleep 5 }
```

### 4.3 — Sincronizar tudo

Com `syncPolicy.automated` configurado, o ArgoCD sincroniza
automaticamente assim que as Applications são criadas.
Mas você pode forçar manualmente:

```bash
argocd app sync root
# O sync da root dispara o sync das filhas em cascata
```

---

## Fase 5 — Observar o Deploy Automático

### 5.1 — Acompanhar na UI

Abra: http://localhost:8080

Você verá o gráfico de dependências de cada Application:
- `mario` → Deployment, Service, HPA
- `prometheus-stack` → Prometheus, Grafana, Alertmanager...
- `minio` → StatefulSet (sync wave -1, sobe primeiro)
- `mimir` → StatefulSet (sobe após MinIO)
- `tempo` + `pyroscope` + `alloy` → traces e profiling
- `opentelemetry` + `profiler-manifests` → ranking-api + carga automática

### 5.2 — Verificar via kubectl

```bash
# Todos os pods
kubectl get pods -A

# Status das Applications
argocd app list
# Esperado: todas com STATUS=Synced, HEALTH=Healthy
```

### 5.3 — Verificar os serviços externos

```bash
# Linux / macOS
curl http://localhost:8081         # Mario — responde com HTML
curl http://localhost:9009/ready   # Mimir — "ready"
```
```pwsh
# Windows (PowerShell)
Invoke-RestMethod http://localhost:8081        # Mario — retorna HTML
Invoke-RestMethod http://localhost:9009/ready  # Mimir — "ready"
```

Ou abra no browser:
- Grafana: http://localhost:3000 (admin / prom-operator)
- ArgoCD: http://localhost:8080

---

## Fase 6 — GitOps Loop: Mudança via Git ⭐

> Esta é a essência do GitOps: **você não aplica mudanças diretamente
> no cluster**. Você modifica o repositório e o ArgoCD sincroniza.

### 6.1 — Aumentar as réplicas do Mario via git

```bash
# Edite o arquivo
# stack/mario/01-deployment-mario.yaml
# Mude: replicas: 2  →  replicas: 4
```

```bash
# Commit e push
git add stack/mario/01-deployment-mario.yaml
git commit -m "scale: mario replicas 2 → 4"
git push gitea main
```

### 6.2 — Observar o sync automático

O ArgoCD verifica o repositório a cada **3 minutos** por padrão.
Para forçar sync imediato:

```bash
argocd app sync mario
```

Na UI, observe o Deployment `super-mario` escalar para 4 réplicas em tempo real.

```bash
kubectl get pods -n games -w
# Você verá novos pods sendo criados
```

### 6.3 — Reverter a mudança (rollback via git)

```bash
# Git revert (método GitOps correto — não use kubectl!)
git revert HEAD
git push gitea main

# Ou se quiser forçar um rollback direto
argocd app rollback mario
```

---

## Fase 7 — Self-Healing: ArgoCD vs kubectl manual ⭐

> O ArgoCD com `selfHeal: true` detecta mudanças feitas diretamente
> no cluster (fora do git) e as reverte automaticamente.

### 7.1 — Deletar o Deployment do Mario manualmente

```bash
kubectl delete deployment super-mario -n games
```

### 7.2 — Observar o self-healing

No ArgoCD, o `mario` ficará brevemente `OutOfSync → Degraded → Syncing → Healthy`.
Em segundos, o Deployment é recriado automaticamente.

```bash
kubectl get deployment super-mario -n games -w
# O Deployment desaparece e reaparece em ~10-30 segundos
```

> **Mensagem importante**: em ambientes com ArgoCD e `selfHeal: true`,
> **nunca use `kubectl apply/delete` direto em produção**.
> A fonte de verdade é o repositório. Mudanças manuais são revertidas.

### 7.3 — Tentar modificar uma configuração manualmente

```bash
# Tente mudar as réplicas via kubectl
kubectl scale deployment super-mario -n games --replicas=10

# Observe que logo volta para 4 (ou 2, conforme o git)
kubectl get deployment super-mario -n games
```

---

## Fase 8 — Sync Wave: Ordem de Deploy Controlada

O ArgoCD deploya resources dentro de uma Application na seguinte ordem:
1. Namespaces
2. Resources com `sync-wave: -2` (menor primeiro)
3. Resources com `sync-wave: -1`
4. Resources com `sync-wave: 0` (padrão)
5. ...

Entre Applications:
- `minio` tem `argocd.argoproj.io/sync-wave: "-1"` → sincroniza primeiro
- `mimir` não tem annotation → `wave: 0` → sincroniza após MinIO

Verifique o comportamento fazendo um sync manual da `root`:

```bash
argocd app sync root --sync-option ApplyOutOfSyncOnly=true
```

Observe na UI a ordem em que as Applications ficam verdes.

---

## Troubleshooting

### Application presa em "Unknown" ou "OutOfSync"

```bash
# Ver detalhes de erro
argocd app get mario
argocd app get mario --show-operation

# Forçar refresh do repositório
argocd app get mario --refresh
```

### ArgoCD não consegue clonar o repositório

```bash
# Linux / macOS
kubectl run -n argocd -it --rm debug --image=busybox --restart=Never -- \
  wget -q -O- http://gitea-http.gitea.svc.cluster.local:3000
# Esperado: HTML do Gitea
```
```pwsh
# Windows (PowerShell)
kubectl run -n argocd -it --rm debug --image=busybox --restart=Never -- `
  wget -q -O- http://gitea-http.gitea.svc.cluster.local:3000
# Esperado: HTML do Gitea
```

```bash
# Verificar credentials do repo
argocd repo list
```

### Helm chart com "OutOfSync" constante (ignorar campos)

Alguns Helm charts geram valores dinâmicos (ex: timestamps, UIDs) que
o ArgoCD detecta como diff a cada sync. Solução: `ignoreDifferences`:

```yaml
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/template/metadata/annotations/checksum
```

### Push para o Gitea recusa ("rejected")

```bash
# O branch padrão pode ser "master" em vez de "main"
git push gitea master
# ou
git push gitea HEAD:main
```
