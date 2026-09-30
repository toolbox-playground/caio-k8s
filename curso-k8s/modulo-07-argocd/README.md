# Módulo 07 — Argo CD

> *"Segunda-feira de manhã. Um engenheiro sênior aplica um patch no cluster
> com `kubectl apply -f arquivo-errado.yaml`. Em minutos, o Deployment de
> produção começa a falhar. Sem ArgoCD: caçar o que mudou, comparar YAML,
> restaurar manualmente. Com ArgoCD: `git revert + push` — o cluster volta
> ao estado esperado em 30 segundos."*

> **Versão coberta neste módulo**: ArgoCD **v3.x** (série estável em 2026).
> Mudanças relevantes em relação ao v2 são destacadas com `⚠️ v3`.

---

## O Que é GitOps

GitOps é uma prática onde o **repositório git é a fonte de verdade** do
estado do cluster. Em vez de executar `kubectl apply` ou `helm install`
manualmente, você:

1. Descreve o estado desejado em YAML no git
2. Faz commit e push
3. Uma ferramenta de CD (ArgoCD) detecta a mudança e aplica no cluster

Benefícios concretos:
- **Auditoria**: todo `git log` é também um log de mudanças no cluster
- **Rollback**: `git revert` é também um rollback de infraestrutura
- **Self-healing**: mudanças manuais no cluster são revertidas automaticamente
- **Multi-ambiente**: um repo git pode gerenciar dev/staging/prod via branches ou paths

---

## Arquitetura do Módulo

```
┌─────────────────────────────────────────────────────────────────┐
│  Você (developer)                                                │
│      git push → Gitea (localhost:33000)                          │
└─────────────────────────────┬───────────────────────────────────┘
                              │  git clone/pull
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     namespace: argocd                            │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                   ArgoCD Controller                      │    │
│  │                                                          │    │
│  │  Application: root ──watches──▶ apps/ no git            │    │
│  │                  ├── Application: mario                  │    │
│  │                  ├── Application: prometheus-stack       │    │
│  │                  ├── Application: loki                   │    │
│  │                  ├── Application: fluent-bit             │    │
│  │                  ├── Application: monitoring-manifests   │    │
│  │                  ├── Application: minio  (wave -1)       │    │
│  │                  └── Application: mimir  (wave  0)       │    │
│  │                  ├── Application: tempo                  │    │
│  │                  ├── Application: pyroscope              │    │
│  │                  ├── Application: alloy  (wave  1)       │    │
│  │                  ├── Application: opentelemetry (wave 1) │    │
│  │                  └── Application: profiler-manifests (2) │    │
│  └────────────────────────┬────────────────────────────────┘    │
│                           │  kubectl apply (server-side)         │
└───────────────────────────┼─────────────────────────────────────┘
                            ▼
         namespaces: games, monitoring (recursos reais)
```

### Fluxo GitOps

```
1. Você edita stack/mario/01-deployment-mario.yaml (replicas: 2 → 4)
2. git commit + git push → Gitea
3. ArgoCD repo server clona o repositório (poll a cada 3min ou webhook)
4. ArgoCD compara estado atual do cluster vs estado desejado no git
5. Detecta diff: Deployment.spec.replicas = 2 (cluster) ≠ 4 (git)
6. Aplica: kubectl apply (server-side) → Deployment.spec.replicas = 4
7. Status da Application: Synced + Healthy
```

---

## Conceitos Centrais

### Application

O recurso central do ArgoCD. Define:
- **sources**: de onde vir os manifests (git path, Helm chart ou múltiplas fontes)
- **destination**: em qual cluster e namespace aplicar
- **project**: AppProject de isolamento (padrão: `default`)
- **syncPolicy**: como e quando sincronizar

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mario
  namespace: argocd
  # Garante cascade delete (foreground) ao remover a Application.
  # /foreground = espera os recursos filhos serem deletados antes de remover a Application.
  finalizers:
    - resources-finalizer.argocd.argoproj.io/foreground
spec:
  project: default
  # ⚠️ v3: use sempre "sources" (plural) — "source" singular foi depreciado.
  # Mesmo para source única, use a lista:
  sources:
    - repoURL: http://gitea-http.gitea.svc.cluster.local:3000/gitops/caio-k8s.git
      targetRevision: HEAD
      path: curso-k8s/modulo-07-argocd/stack/mario
  destination:
    server: https://kubernetes.default.svc
    namespace: games
  syncPolicy:
    automated:
      prune: true    # deleta resources removidos do git
      selfHeal: true # reverte mudanças manuais no cluster
    syncOptions:
      - CreateNamespace=true    # cria o namespace se não existir
      - ServerSideApply=true    # usa SSA em vez de client-side apply (v3 padrão)
      - ApplyOutOfSyncOnly=true # otimiza sync: aplica só o que mudou
```

> **v3 — `sources` (plural) é o padrão canônico**: o campo `source` (singular)
> foi **depreciado** no ArgoCD v3. Use sempre `sources` como lista, mesmo
> quando há apenas uma fonte. O campo `source` ainda funciona mas será removido
> em versão futura.

---

### App of Apps

Uma Application que gerencia outras Applications.
A `root` assiste `apps/` no git. Quando você adiciona `apps/08-nova-app.yaml`,
o ArgoCD automaticamente cria a nova Application sem intervenção manual.

```
root (Application)
  └── watches: apps/ no git
        ├── 01-mario-app.yaml      → Application mario
        ├── 02-prometheus-app.yaml → Application prometheus-stack
        └── ...
```

**v3 — Finalizers no App of Apps**: para que deletar a Application-pai
também delete as filhas em cascata, inclua o finalizer:

```yaml
metadata:
  finalizers:
    # Foreground cascading delete (padrão — espera recursos filhos serem deletados)
    - resources-finalizer.argocd.argoproj.io/foreground
    # Alternativa: background cascading delete (mais rápido, não espera)
    # - resources-finalizer.argocd.argoproj.io/background
```

Sem o finalizer, deletar a `root` deixa as Applications filhas órfãs no cluster.

---

### ApplicationSet (alternativa moderna ao App of Apps)

O `ApplicationSet` é um CRD separado que cria Applications dinamicamente
a partir de **geradores** (git directories, listas, clusters, Pull Requests, etc.).
É mais poderoso que o App of Apps para cenários multi-cluster ou multi-tenant.

```yaml
# Exemplo: cria uma Application para cada subdiretório em apps/
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: all-apps
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
    - git:
        repoURL: http://gitea-http.gitea.svc.cluster.local:3000/gitops/caio-k8s.git
        revision: HEAD
        directories:
          - path: curso-k8s/modulo-07-argocd/stack/*
  template:
    metadata:
      name: '{{.path.basename}}'
    spec:
      project: default
      # ⚠️ v3: use "sources" (plural) mesmo dentro de templates ApplicationSet
      sources:
        - repoURL: http://gitea-http.gitea.svc.cluster.local:3000/gitops/caio-k8s.git
          targetRevision: HEAD
          path: '{{.path.path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{.path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
          - ServerSideApply=true
```

> Este módulo usa **App of Apps** por ser mais didático e explícito.
> Em produção, ApplicationSet é recomendado para gerenciar dezenas de apps.

---

### Sync Wave

Controla a **ordem de deploy** dentro de um sync. Essencial para dependências.
Recursos com wave menor sobem **antes**. O padrão é `wave: 0`.

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"  # sobe antes dos wave 0
```

Neste módulo: AIStor/MinIO (`wave: -1`) → Mimir (`wave: 0`, padrão).

**Hooks** funcionam em conjunto com waves para ações antes/após o sync:

| Hook | Quando executa |
|---|---|
| `PreSync` | Antes de aplicar qualquer resource (ex: migrations de banco) |
| `Sync` | Durante o sync, no wave indicado |
| `PostSync` | Após todos os resources estarem Healthy (ex: notificações) |
| `SyncFail` | Se o sync falhar |

```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    argocd.argoproj.io/sync-wave: "-1"
```

---

### Multi-Source

Applications onde o **chart Helm** vem de um Helm repo e os **values**
vêm do repositório git. Introduzido no ArgoCD 2.6, **estável e canônico no v3.x**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  sources:
    - repoURL: https://prometheus-community.github.io/helm-charts
      chart: kube-prometheus-stack
      targetRevision: "x.y.z"
      helm:
        valueFiles:
          - $values/curso-k8s/modulo-07-argocd/stack/monitoring/helm-values/values-prometheus-stack.yaml
    - repoURL: http://gitea-http.gitea.svc.cluster.local:3000/gitops/caio-k8s.git
      targetRevision: HEAD
      ref: values   # ← cria o alias "$values" usado acima
```

> **⚠️ v3**: no v3 o campo `source` (singular) foi **depreciado** em favor de
> `sources` (plural). Todas as Applications multi-source já eram obrigadas a
> usar `sources`; Applications com source única devem migrar para o plural também.

---

### Source Hydrator (novo no v3)

Feature v3 que permite escrever manifests **hidratados** (processados pelo Helm/Kustomize)
em um branch git separado, separando a fonte "dry" do deploy "wet":

```yaml
spec:
  sourceHydrator:
    drySource:
      repoURL: https://github.com/my-org/config
      path: helm-guestbook
      targetRevision: HEAD
    syncSource:
      targetBranch: environments/dev
      path: helm-guestbook-hydrated
```

> Avançado — não usado neste módulo. Útil para auditorias de manifest exato.

---

### Sync Policies e syncOptions

| Campo | Comportamento |
|---|---|
| Manual (sem `automated`) | Sync só quando pedido (`argocd app sync`) |
| `automated` | Sync automático ao detectar diff no git |
| `automated.prune: true` | Remove recursos deletados do git |
| `automated.selfHeal: true` | Reverte mudanças manuais no cluster |

**syncOptions** configuráveis por Application:

| Opção | Descrição |
|---|---|
| `CreateNamespace=true` | Cria o namespace destino se não existir |
| `ServerSideApply=true` | Usa Server-Side Apply (SSA) — padrão em v3 |
| `ApplyOutOfSyncOnly=true` | Aplica somente resources fora de sincronia |
| `PruneLast=true` | Faz prune apenas após o sync completo |
| `SkipDryRunOnMissingResource=true` | Ignora dry-run quando CRDs ainda não existem |
| `Validate=false` | Desativa validação de schema (útil com SSA parcial) |
| `Replace=true` | Substitui o resource em vez de patch (destrutivo!) |

---

### Health Status

Cada resource tem um status de saúde calculado pelo ArgoCD:

| Status | Significado |
|---|---|
| `Healthy` | Resource está operacional e pronto |
| `Progressing` | Resource está sendo criado/atualizado |
| `Degraded` | Resource falhou ou não atingiu o estado desejado |
| `Suspended` | Resource pausado intencionalmente (ex: CronJob) |
| `Missing` | Resource existe no git mas não no cluster |
| `Unknown` | Não é possível determinar o status |

Para ignorar a saúde de um resource filho específico na saúde da Application pai:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/ignore-healthcheck: "true"
```

---

## Estrutura do Módulo

```
modulo-07-argocd/
├── cluster-config.yaml         # Kind + portas ArgoCD (8080) e Gitea (33000)
├── QUICK-START.md
├── README.md
│
├── install/
│   ├── values-argocd.yaml              # Helm values do ArgoCD (NodePort 30080, insecure)
│   ├── values-gitea.yaml               # Helm values do Gitea (NodePort 33000)
│   ├── values-aistor-operator.yaml     # AIStor Operator (instalar UMA VEZ, namespace aistor)
│   └── values-aistor-objectstore.yaml  # AIStor ObjectStore (S3 p/ o Mimir)
│
├── apps/                       ← ArgoCD Application manifests
│   ├── 00-root-app.yaml        # App of Apps — criado manualmente
│   ├── 01-mario-app.yaml       # Application: Mario (manifests)
│   ├── 02-prometheus-app.yaml  # Application: kube-prometheus-stack (Helm multi-source)
│   ├── 03-loki-app.yaml        # Application: Loki (Helm multi-source)
│   ├── 04-fluent-bit-app.yaml  # Application: Fluent Bit (Helm multi-source)
│   ├── 05-monitoring-manifests-app.yaml  # Application: dashboards + alerts
│   ├── 06-minio-app.yaml       # Application: AIStor ObjectStore (sync wave -1)
│   ├── 07-mimir-app.yaml       # Application: Mimir (manifests)
│   ├── 08-tempo-app.yaml       # Application: Tempo (Helm)
│   ├── 09-pyroscope-app.yaml   # Application: Pyroscope (Helm)
│   ├── 10-alloy-app.yaml       # Application: Alloy eBPF (Helm)
│   ├── 11-opentelemetry-app.yaml      # Application: OTel Collector + Service
│   └── 12-profiler-manifests-app.yaml # Application: ranking-api + load
│
└── stack/                      ← Manifests que as Applications deployam
    ├── mario/
    ├── minio/
    ├── monitoring/
    │   ├── helm-values/
    │   └── manifests/
    ├── opentelemetry/
    ├── profiler/
    └── mimir/
        └── manifests/
```

---

## Comparação: Manual vs GitOps

| Operação | Manual (módulos anteriores) | GitOps (ArgoCD) |
|---|---|---|
| Deploy inicial | `helm install && kubectl apply` | `kubectl apply -f 00-root-app.yaml` |
| Atualizar config | `kubectl apply -f novo.yaml` | `git commit && git push` |
| Rollback | `helm rollback` ou `kubectl apply` antigo | `git revert && git push` |
| Quem aplicou essa mudança? | Difícil rastrear | `git log` |
| Cluster divergiu do esperado? | Não detectado | ArgoCD alerta + corrige |
| Deletar recurso acidentalmente | Dados perdidos até alguém notar | Self-healing restaura em segundos |

---

## Mudanças Relevantes no ArgoCD v3

| Mudança | Impacto prático |
|---|---|
| `source` singular **depreciado** → use `sources` (plural) | Migrar YAMLs existentes |
| Server-Side Apply (SSA) é o **padrão** para novas instâncias | `kubectl.kubernetes.io/last-applied-configuration` não é mais adicionado por padrão |
| Dex SSO: RBAC usa `federated_claims.user_id` (não mais `sub`) | Policies existentes com hash base64 precisam ser reescritas com email legível |
| `resourceHealthSource: appTree` é o padrão — saúde **não persiste** mais por recurso no status | Para persistir (comportamento v2): set `controller.resource.health.persist: true` no argocd-cm |
| ApplicationSet: `applyNestedSelectors` desabilitado por padrão | ApplicationSets com selector aninhado em generators Matrix/Merge precisam de atualização |
| `ClientSideApplyMigration=true` habilitado por padrão | Recursos migram automaticamente para SSA no próximo sync |

---

## Portas Expostas

| Serviço | URL | Credenciais |
|---|---|---|
| ArgoCD | http://localhost:8080 | admin / `argocd admin initial-password -n argocd` |
| Gitea | http://localhost:33000 | gitops / gitops-secret |
| Grafana | http://localhost:3000 | admin / prom-operator |
| Prometheus | http://localhost:9090 | — |
| Mario | http://localhost:8081 | — |
| Mimir API | http://localhost:9009 | — |
| AIStor Console (S3) | http://localhost:9001 | mimir / mimir-supersecret |

---

## Referências

- [Argo CD Docs (stable)](https://argo-cd.readthedocs.io/en/stable/)
- [Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [ApplicationSet](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/)
- [Sync Waves & Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
- [Sync Options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)
- [Multi-Source Applications](https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/)
- [Source Hydrator (v3)](https://argo-cd.readthedocs.io/en/stable/user-guide/source-hydrator/)
- [Health Checks](https://argo-cd.readthedocs.io/en/stable/operator-manual/health/)
- [RBAC](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/)
- [Upgrading v2.14 → v3.0](https://argo-cd.readthedocs.io/en/stable/operator-manual/upgrading/2.14-3.0/)
- [GitOps Principles](https://opengitops.dev/)

