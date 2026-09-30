# Módulo 08 — Flux

> *"Terça-feira de manhã. O mesmo engenheiro sênior do módulo anterior,
> desta vez usando Flux. Ele edita um Deployment, faz `git push` para o
> repositório. Em 3 minutos o Flux detecta a mudança e aplica. Sem CLI,
> sem kubectl direto no cluster — só git. Quando ele tenta fazer um
> `kubectl edit` manual para 'corrigir rapidamente' algo em produção,
> o Flux reverte automaticamente em segundos. Git é a única fonte de verdade."*

> **Versão coberta neste módulo**: Flux **v2.x** (série estável em 2026).
> CLI: `flux` v2.x. CRDs: `source.toolkit.fluxcd.io/v1`, `kustomize.toolkit.fluxcd.io/v1`,
> `helm.toolkit.fluxcd.io/v2`.

---

## O Que é Flux

Flux é uma ferramenta de **GitOps contínuo** para Kubernetes, criada pela CNCF
(atualmente projeto graduado). Assim como o ArgoCD, o Flux garante que o estado
do cluster reflita o que está no repositório git.

A diferença filosófica central:

| | ArgoCD | Flux |
|---|---|---|
| Modelo de UI | Interface web rica (UI + CLI + API) | CLI-first (sem UI oficial) |
| Unidade central | `Application` (CRD único) | Composição de CRDs (`Kustomization` + `HelmRelease` + `GitRepository` + ...) |
| App of Apps | Padrão explícito | Diretório + Kustomization recursivo |
| Bootstrap | Manual (`kubectl apply`) | `flux bootstrap` (self-managed via git) |
| Notificações | Nativo + webhook | `Notification Controller` separado |
| Multi-tenancy | AppProject | Tenant isolation via namespace + RBAC |
| Ecosystem | Argo Workflows, Rollouts, Events | Flagger (canary), Image Automation |

Ambos são soluções de GitOps maduras. A escolha depende de preferências de equipe.

---

## Arquitetura do Módulo

```
┌─────────────────────────────────────────────────────────────────┐
│  Você (developer)                                                │
│      git push → Gitea (localhost:33000)                          │
└─────────────────────────────┬───────────────────────────────────┘
                              │  git clone/pull (poll a cada 1min)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   namespace: flux-system                         │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Source Controller                            │   │
│  │   GitRepository: caio-k8s ──▶ clona o repositório        │   │
│  │   HelmRepository: prometheus, grafana, minio, ...        │   │
│  └───────────────────────┬──────────────────────────────────┘   │
│                          │  Artifact (tar.gz do git / index)     │
│  ┌───────────────────────▼──────────────────────────────────┐   │
│  │           Kustomize Controller                            │   │
│  │   Kustomization: flux-sources ──▶ cria HelmRepositories  │   │
│  │   Kustomization: flux-apps    ──▶ cria HelmReleases      │   │
│  │   Kustomization: mario        ──▶ aplica manifests       │   │
│  │   Kustomization: mimir        ──▶ aplica manifests       │   │
│  │   (dependsOn: minio)                                      │   │
│  └───────────────────────┬──────────────────────────────────┘   │
│                          │                                        │
│  ┌───────────────────────▼──────────────────────────────────┐   │
│  │              Helm Controller                              │   │
│  │   HelmRelease: prometheus-stack  ──▶ helm install        │   │
│  │   HelmRelease: loki, tempo, ...  ──▶ helm install        │   │
│  │   HelmRelease: minio (manda: mimir-kustomization)        │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                            │  kubectl apply (server-side)
                            ▼
         namespaces: games, monitoring (recursos reais)
```

### Fluxo GitOps

```
1. Você edita stack/mario/01-deployment-mario.yaml (replicas: 2 → 4)
2. git commit + git push → Gitea
3. Source Controller detecta mudança (poll 1min ou webhook)
4. Kustomize Controller reconcilia Kustomization "mario"
5. Detecta diff: Deployment.spec.replicas = 2 (cluster) ≠ 4 (git)
6. Aplica: kubectl apply (server-side) → Deployment.spec.replicas = 4
7. Kustomization status: Ready = True
```

---

## Componentes do Flux

O Flux é composto por **controllers** independentes, cada um responsável por
um tipo de recurso:

### Source Controller
Busca e cacheia fontes de dados. Cria `Artifact` (tar.gz assinado) que os
demais controllers consomem:

| CRD | O que faz |
|---|---|
| `GitRepository` | Clona um repositório git (SSH ou HTTPS) |
| `HelmRepository` | Indexa um repositório Helm (OCI ou HTTP) |
| `OCIRepository` | Puxa imagem OCI (container registry) |
| `Bucket` | Acessa objetos em S3/GCS/MinIO |

### Kustomize Controller
Aplica manifests Kubernetes a partir de um `Artifact`. Suporta:
- Diretórios com `kustomization.yaml` (Kustomize nativo)
- Diretórios sem `kustomization.yaml` (cria um temporário automaticamente)
- Post-build variable substitution (`postBuild.substitute`)
- Criptografia de Secrets com SOPS

### Helm Controller
Gerencia o ciclo de vida de releases Helm:
- Install, Upgrade, Rollback, Uninstall
- Drift detection e remediation
- Valores de ConfigMaps/Secrets via `valuesFrom`

### Notification Controller
Envia eventos para sistemas externos (Slack, Discord, PagerDuty, etc.)
e recebe webhooks para triggering de reconciliação imediata.

### Image Automation Controllers (opcional)
Detecta novas tags de imagem no registry e atualiza automaticamente
os manifests no repositório git.

---

## Conceitos Centrais

### GitRepository

Define a origem do código. O Source Controller poleia periodicamente:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: caio-k8s
  namespace: flux-system
spec:
  interval: 1m           # frequência de poll
  url: http://gitea-http.gitea.svc.cluster.local:3000/gitops/caio-k8s.git
  ref:
    branch: main
  # Para repos privados: secretRef com credentials SSH ou HTTPS
  # secretRef:
  #   name: gitea-credentials
```

### HelmRepository

Registra um repositório Helm. O Source Controller baixa o index:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: prometheus-community
  namespace: flux-system
spec:
  interval: 1h
  url: https://prometheus-community.github.io/helm-charts
```

### Kustomization (Flux CRD)

⚠️ **Atenção**: existe `Kustomization` do Flux (`kustomize.toolkit.fluxcd.io/v1`)
e `Kustomization` da ferramenta Kustomize (`kustomize.config.k8s.io/v1beta1`).
São recursos **diferentes**. No contexto Flux, sempre se refere ao CRD do Flux.

O Flux Kustomization define **o quê e onde** aplicar:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: mario
  namespace: flux-system
spec:
  interval: 5m              # frequência de reconciliação
  path: ./curso-k8s/modulo-07-argocd/stack/mario
  sourceRef:
    kind: GitRepository
    name: caio-k8s
  prune: true               # deleta recursos removidos do git (= ArgoCD prune)
  targetNamespace: games
  postBuild:
    substitute:
      ENV: production
```

### HelmRelease

Gerencia um release Helm. O Helm Controller instala/atualiza automaticamente:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: prometheus-stack
  namespace: flux-system
spec:
  interval: 10m
  chart:
    spec:
      chart: kube-prometheus-stack
      version: "*"
      sourceRef:
        kind: HelmRepository
        name: prometheus-community
  targetNamespace: monitoring
  install:
    createNamespace: true
  # Valores vindos de ConfigMap (criado via Kustomize configMapGenerator)
  valuesFrom:
    - kind: ConfigMap
      name: prometheus-stack-values
      valuesKey: values-prometheus-stack.yaml
```

### dependsOn — Equivalente ao Sync Wave

O `dependsOn` garante **ordem de reconciliação** entre Kustomizations e
HelmReleases. É o equivalente do `argocd.argoproj.io/sync-wave` do ArgoCD.

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: mimir
  namespace: flux-system
spec:
  dependsOn:
    - name: minio          # Aguarda minio estar Ready antes de aplicar
  interval: 5m
  path: ./curso-k8s/modulo-07-argocd/stack/mimir/manifests
  sourceRef:
    kind: GitRepository
    name: caio-k8s
  prune: true
  targetNamespace: monitoring
```

Diferente do sync wave (número inteiro), `dependsOn` é explícito por nome.
Isso é mais legível mas menos flexível para ordens complexas.

### valuesFrom + configMapGenerator

Para passar values de um arquivo git para um HelmRelease, o Flux usa uma
combinação de:
1. `configMapGenerator` no `kustomization.yaml` (Kustomize tool)
2. `valuesFrom` no `HelmRelease`

O Kustomize Controller processa o `kustomization.yaml`, cria o ConfigMap,
e então o Helm Controller usa-o via `valuesFrom`:

```yaml
# kustomization.yaml (Kustomize tool config — não é o CRD do Flux)
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - helmrelease-prometheus.yaml
configMapGenerator:
  - name: prometheus-stack-values
    files:
      - values-prometheus-stack.yaml=../../../modulo-07-argocd/stack/monitoring/helm-values/values-prometheus-stack.yaml
    options:
      disableNameSuffixHash: true  # evita sufixo de hash no nome
```

> **Alternativa simples**: use `spec.values` inline no HelmRelease para
> valores pequenos, sem necessidade de ConfigMap.

---

## Estrutura do Módulo

```
modulo-08-flux/
├── cluster-config.yaml         # Kind cluster (mesmo do módulo 07)
├── QUICK-START.md
├── README.md
│
├── install/
│   └── values-gitea.yaml               # Mesmo Gitea do módulo 07
│
└── flux/
    ├── flux-system/
    │   └── root-sync.yaml              # GitRepository + Kustomizations raiz (aplicado 1x)
    │
    ├── namespaces/                     # Namespaces games + monitoring
    │   ├── kustomization.yaml
    │   └── namespaces.yaml
    │
    ├── sources/                        # HelmRepositories + GitRepository
    │   ├── kustomization.yaml
    │   ├── helmrepository-prometheus.yaml
    │   ├── helmrepository-grafana.yaml
    │   ├── helmrepository-grafana-community.yaml
    │   ├── helmrepository-fluent.yaml
    │   └── helmrepository-minio.yaml
    │
    └── apps/                           # HelmReleases + Kustomizations de app
        ├── kustomization.yaml          # Kustomize config + configMapGenerators
        ├── 00-namespaces.yaml          # Kustomization (cria namespaces)
        ├── 01-mario.yaml               # Kustomization (manifests)
        ├── 02-prometheus.yaml          # HelmRelease
        ├── 03-loki.yaml                # HelmRelease
        ├── 04-fluent-bit.yaml          # HelmRelease (dependsOn: loki)
        ├── 05-monitoring-manifests.yaml # Kustomization (dependsOn: prometheus-stack)
        ├── 06-minio.yaml               # HelmRelease (storage S3)
        ├── 07-mimir.yaml               # Kustomization (dependsOn: minio)
        ├── 08-tempo.yaml               # HelmRelease
        ├── 09-pyroscope.yaml           # HelmRelease
        ├── 10-alloy.yaml               # HelmRelease (dependsOn: pyroscope)
        ├── 11-opentelemetry.yaml       # Kustomization (dependsOn: monitoring)
        └── 12-profiler-manifests.yaml  # Kustomization (dependsOn: alloy+otel)
```

### Mapeamento ArgoCD → Flux

| ArgoCD (módulo 07) | Flux (módulo 08) | Observação |
|---|---|---|
| `Application` (git manifests) | `Kustomization` | CRD Flux |
| `Application` (Helm chart) | `HelmRelease` + `HelmRepository` | |
| `sources` multi-source | `HelmRepository` + `valuesFrom` | Fontes separadas |
| `argocd.argoproj.io/sync-wave` | `dependsOn` | Por nome, não por número |
| `automated.prune: true` | `prune: true` | Mesmo comportamento |
| `automated.selfHeal: true` | `interval` + drift detection | Flux sempre corrige drift |
| `syncOptions: CreateNamespace` | `install.createNamespace: true` | |
| `syncOptions: ServerSideApply` | `kubeConfig.forceApply: true` (ou padrão SSA) | |
| `00-root-app.yaml` (App of Apps) | `flux-system/root-sync.yaml` | Aplicado manualmente |

---

## Flux vs ArgoCD — Comparação Detalhada

| Critério | ArgoCD v3 | Flux v2 |
|---|---|---|
| **Interface** | UI web + CLI + API | CLI (`flux`) + kubectl |
| **Bootstrap** | Manual (`kubectl apply`) | `flux bootstrap` (auto-manage) |
| **Unidade de deploy** | `Application` (all-in-one) | `Kustomization` + `HelmRelease` compostos |
| **Multi-source** | `sources[]` nativo | `HelmRepository` separado + `valuesFrom` |
| **Ordering** | Sync Waves (números) | `dependsOn` (por nome) |
| **Drift correction** | `selfHeal: true` | Sempre ativo (baseado em interval) |
| **Secret encryption** | External Secrets Operator | SOPS nativo |
| **Canary/progressive** | Argo Rollouts | Flagger |
| **Notificações** | Plugin nativo | Notification Controller |
| **Multi-cluster** | ApplicationSet + generators | Kustomization por cluster |
| **RBAC** | AppProject + RBAC | Namespace isolation + Kyverno/OPA |
| **Curva de aprendizado** | Menor (UI ajuda) | Maior (necessita entender CRDs compostos) |

---

## Portas Expostas

| Serviço | URL | Credenciais |
|---|---|---|
| Gitea | http://localhost:33000 | gitops / gitops-secret |
| Grafana | http://localhost:3000 | admin / prom-operator |
| Prometheus | http://localhost:9090 | — |
| Mario | http://localhost:8081 | — |
| Mimir API | http://localhost:9009 | — |
| AIStor Console (S3) | http://localhost:9001 | mimir / mimir-supersecret |

> **Nota**: o Flux não possui UI web. O controle é feito via `flux` CLI e `kubectl`.
> Para visualização, use `flux get all -A` ou o plugin Weave GitOps (opcional).

---

## Referências

- [Flux Docs (stable)](https://fluxcd.io/flux/)
- [Get Started with Flux](https://fluxcd.io/flux/get-started/)
- [Core Concepts](https://fluxcd.io/flux/concepts/)
- [GitRepository CRD](https://fluxcd.io/flux/components/source/gitrepositories/)
- [HelmRepository CRD](https://fluxcd.io/flux/components/source/helmrepositories/)
- [Kustomization CRD](https://fluxcd.io/flux/components/kustomize/kustomizations/)
- [HelmRelease CRD](https://fluxcd.io/flux/components/helm/helmreleases/)
- [dependsOn](https://fluxcd.io/flux/components/kustomize/kustomizations/#dependencies)
- [valuesFrom](https://fluxcd.io/flux/components/helm/helmreleases/#values-references)
- [SOPS Secrets](https://fluxcd.io/flux/guides/mozilla-sops/)
- [Troubleshooting Cheatsheet](https://fluxcd.io/flux/cheatsheets/troubleshooting/)
- [Flux vs Argo CD](https://fluxcd.io/blog/2022/11/flux-vs-argo-cd/)
