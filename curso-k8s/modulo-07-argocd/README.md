# Módulo 07 — Argo CD

> *"Segunda-feira de manhã. Um engenheiro sênior aplica um patch no cluster
> com `kubectl apply -f arquivo-errado.yaml`. Em minutos, o Deployment de
> produção começa a falhar. Sem ArgoCD: caçar o que mudou, comparar YAML,
> restaurar manualmente. Com ArgoCD: `git revert + push` — o cluster volta
> ao estado esperado em 30 segundos."*

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
6. Aplica: kubectl apply → Deployment.spec.replicas = 4
7. Status da Application: Synced + Healthy
```

---

## Conceitos Centrais

### Application

O recurso central do ArgoCD. Define:
- **source**: de onde vir os manifests (git path ou Helm chart)
- **destination**: em qual cluster e namespace aplicar
- **syncPolicy**: como e quando sincronizar

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  source:
    repoURL: http://gitea-http.gitea.svc.cluster.local:3000/gitops/caio-k8s.git
    path: curso-k8s/modulo-07-argocd/stack/mario
  destination:
    server: https://kubernetes.default.svc
    namespace: games
  syncPolicy:
    automated:
      prune: true    # deleta resources removidos do git
      selfHeal: true # reverte mudanças manuais no cluster
```

### App of Apps

Uma Application que gerencia outras Applications.
A `root` assiste `apps/` no git. Quando você adiciona `apps/08-nova-app.yaml`,
o ArgoCD automaticamente cria a nova Application sem intervenção manual.

```
root (Application)
  └── watches: apps/ no git
        ├── 01-mario-app.yaml     → Application mario
        ├── 02-prometheus-app.yaml → Application prometheus-stack
        └── ...
```

### Sync Wave

Controla a **ordem de deploy** dentro de um sync. Useful para dependências:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"  # sobe antes dos outros
```

Neste módulo: MinIO (wave -1) → Mimir (wave 0, padrão).

### Multi-Source

Applications Helm onde o chart vem de um Helm repo mas os values
vêm do repositório git. Disponível no ArgoCD 2.6+:

```yaml
sources:
  - repoURL: https://prometheus-community.github.io/helm-charts
    chart: kube-prometheus-stack
    helm:
      valueFiles:
        - $values/curso-k8s/modulo-07-argocd/stack/.../values-*.yaml
  - repoURL: <git-repo>
    ref: values  # ← cria o alias "$values"
```

### Sync Policies

| Política | Comportamento |
|---|---|
| Manual (nenhuma) | Sync só quando você pedir (`argocd app sync`) |
| `automated` | Sync automático quando detecta diff no git |
| `automated + prune` | Remove recursos deletados do git |
| `automated + selfHeal` | Reverte mudanças manuais no cluster |

---

## Estrutura do Módulo

```
modulo-07-argocd/
├── cluster-config.yaml         # Kind + portas ArgoCD (8080) e Gitea (33000)
├── QUICK-START.md
├── README.md
│
├── install/
│   ├── values-argocd.yaml      # Helm values do ArgoCD (NodePort 30080, insecure)
│   └── values-gitea.yaml       # Helm values do Gitea (NodePort 33000)
│
├── apps/                       ← ArgoCD Application manifests
│   ├── 00-root-app.yaml        # App of Apps — criado manualmente
│   ├── 01-mario-app.yaml       # Application: Mario (manifests)
│   ├── 02-prometheus-app.yaml  # Application: kube-prometheus-stack (Helm multi-source)
│   ├── 03-loki-app.yaml        # Application: Loki (Helm multi-source)
│   ├── 04-fluent-bit-app.yaml  # Application: Fluent Bit (Helm multi-source)
│   ├── 05-monitoring-manifests-app.yaml  # Application: dashboards + alerts
│   ├── 06-minio-app.yaml       # Application: MinIO (sync wave -1)
│   └── 07-mimir-app.yaml       # Application: Mimir (manifests)
│
└── stack/                      ← Manifests que as Applications deployam
    ├── mario/
    ├── monitoring/
    │   ├── helm-values/
    │   └── manifests/
    └── mimir/
        ├── helm-values/
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

## Portas Expostas

| Serviço | URL | Credenciais |
|---|---|---|
| ArgoCD | http://localhost:8080 | admin / `kubectl get secret argocd-initial-admin-secret` |
| Gitea | http://localhost:33000 | gitops / gitops-secret |
| Grafana | http://localhost:3000 | admin / prom-operator |
| Prometheus | http://localhost:9090 | — |
| Mario | http://localhost:8081 | — |
| Mimir API | http://localhost:9009 | — |
| MinIO Console | http://localhost:9001 | mimir / mimir-supersecret |

---

## Referências

- [Argo CD Docs](https://argo-cd.readthedocs.io/en/stable/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Sync Waves & Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
- [Multi-Source Applications](https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/)
- [GitOps Principles](https://opengitops.dev/)
