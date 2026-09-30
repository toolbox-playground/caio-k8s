# Módulo 11 — GitOps de Produção: ArgoCD + Helm + ESO + Gateway API + Telemetria

> **Módulo 100% independente.** Não exige nenhum módulo anterior, nenhum
> cluster pré-existente e nenhuma stack instalada antes. Ele cria o próprio
> cluster (`gitops-prod`) e o ArgoCD instala o resto **a partir do Git**.
> Os mesmos manifests funcionam em EKS, GKE, AKS ou on-prem (veja
> [Levando para produção](#levando-para-produção)).

## O que você vai construir

Um fluxo de entrega em que **ninguém executa `kubectl apply` ou `helm install`
para publicar uma versão**. O Git é a única fonte de verdade:

```
 ┌──────────────── app-repo (código) ───────────────┐        ┌──────── gitops-repo (estado desejado) ────────┐
 │ push em main                                     │        │ charts/webapp/      Helm chart               │
 │  → pytest                                        │  push  │ envs/dev|staging|prod/values.yaml            │
 │  → build + push GHCR (tag imutável sha-abc1234)  │ ─────► │   └ image.tag  ◄── alterado pelo workflow    │
 │  → Trivy (scan) + Cosign (assinatura)            │  git   │ platform/  Envoy GW, ESO, OTel, Prom, Tempo  │
 │  → workflow altera envs/dev/values.yaml          │        │ bootstrap/ ArgoCD, projetos, root app        │
 └──────────────────────────────────────────────────┘        └───────────────────┬──────────────────────────┘
                                                                                 │ pull (a cada 60s / webhook)
                          ┌──────────────────────────── Cluster ─────────────────▼───────────────────────────┐
                          │ ArgoCD ─ concilia ─► webapp-dev | webapp-staging | webapp-prod                    │
                          │   ├─ Envoy Gateway (Gateway API)  ◄── tráfego externo                             │
                          │   ├─ External Secrets Operator    ◄── cofre de segredos (fake no lab)             │
                          │   └─ OTel Collector → Tempo (traces) · Prometheus → Grafana (métricas)            │
                          └───────────────────────────────────────────────────────────────────────────────────┘
```

O **CI nunca tem acesso ao cluster**: ele só escreve no Git (push). Quem aplica
é o ArgoCD, de dentro (pull). Se o CI for comprometido, o atacante não ganha
`kubeconfig`.

## Decisões de design (e por quê)

| Decisão | Motivo |
| :--- | :--- |
| **2 repositórios** (app + gitops) | Ciclos de vida e permissões diferentes. Commit de deploy não dispara CI de código (sem loops), e o histórico do gitops-repo é uma trilha de auditoria limpa de "quem mudou o quê em prod". |
| **Tag imutável `sha-<7>`**, nunca `latest` | Reprodutibilidade e rollback determinístico. Cada versão em cada ambiente é rastreável até um commit. |
| **Promoção por PR** (dev automático → staging PR → prod PR + aprovação + sync manual) | Aprovação humana e CODEOWNERS exatamente onde o risco está. |
| **Só promove imagem assinada** (Cosign keyless) | Uma imagem construída fora do pipeline não chega em produção. |
| **ApplicationSet** | Um template gera `webapp-dev/staging/prod`. Novo ambiente ou cluster = 1 linha. |
| **App-of-apps + sync waves** | Ordem correta: CRDs (Gateway API, ESO) → configs → apps. |
| **AppProject `workloads` restrito** | Apps só implantam em `webapp-*` e sem recursos cluster-scoped: um `values.yaml` malicioso não escala privilégio. |
| **External Secrets Operator** | Nenhum segredo no Git. Trocar o cofre = trocar 1 `ClusterSecretStore`; charts não mudam. |
| **Gateway API (Envoy Gateway)** | Padrão sucessor do Ingress, portável entre implementações. Plataforma dona do `Gateway`, times donos do `HTTPRoute`. |
| **Versões de chart pinadas** | Upgrade de plataforma é um PR revisável, nunca uma surpresa. |

## Estrutura

```
modulo-11-gitops-producao/
├── README.md                     ← você está aqui
├── QUICK-START.md                ← só os comandos
├── cluster-config.yaml           ← kind: 1 control-plane + 2 workers, portas 8080/18088/3000
├── scripts/
│   ├── bootstrap.sh              ← cria cluster, instala ArgoCD, aplica root app
│   ├── local-lab.sh              ← lab 100% local: Gitea + Actions + registry (sem GitHub)
│   └── teardown.sh
├── app-repo/                     ← ➊ vira o REPO DE CÓDIGO (ex.: minha-org/webapp)
│   ├── app/main.py               API FastAPI: /version /secret /work /metrics, traces OTLP
│   ├── tests/  Dockerfile  requirements*.txt
│   └── .github/workflows/
│       ├── ci-cd.yml             test → build → scan → sign → atualiza gitops-repo (dev)
│       └── promote.yml           abre PR de promoção (staging/prod), valida assinatura
│   └── .gitea/workflows/ci-cd.yml   variante do pipeline para o lab local (Gitea Actions)
└── gitops-repo/                  ← ➋ vira o REPO GITOPS (ex.: minha-org/gitops-repo)
    ├── bootstrap/                values do ArgoCD, AppProjects, root app, registry OCI
    ├── platform/
    │   ├── apps/                 Applications (waves): envoy-gw, eso, config, tempo, otel, prom, workloads
    │   ├── values/               values de cada chart de plataforma
    │   ├── config/               Gateway, EnvoyProxy, ClusterSecretStore, ExternalSecret
    │   └── workloads/            ApplicationSet (dev/staging/prod)
    ├── charts/webapp/            Helm chart (Deployment, HTTPRoute, ExternalSecret, ServiceMonitor, HPA, PDB, NetworkPolicy)
    ├── envs/{dev,staging,prod}/values.yaml   ← image.tag mora aqui
    └── .github/                  validate.yml (helm lint + kubeconform) e CODEOWNERS
```

> `app-repo/` e `gitops-repo/` são **dois repositórios** que, neste curso,
> ficam lado a lado numa pasta. Você vai copiar cada um para um repo GitHub próprio.

## Pré-requisitos (apenas ferramentas — nenhum módulo anterior)

| Ferramenta | Uso |
| :--- | :--- |
| Docker + [kind](https://kind.sigs.k8s.io/) | cluster local (dispensável se você já tem cluster) |
| kubectl, helm ≥ 3.14 | bootstrap |
| git + conta GitHub | 2 repositórios; GHCR para as imagens |
| Recursos | ~6 GB de RAM livres para o Docker |

Se o cluster do Módulo 03/07 (`k8s-essentials`) estiver de pé, **pare-o antes**:
as portas 8080 e 3000 são as mesmas.
```bash
kind delete cluster --name k8s-essentials
```

## Testando localmente (sem GitHub)

**Dá para testar tudo localmente**, inclusive o *workflow*. O script
[scripts/local-lab.sh](./scripts/local-lab.sh) troca cada peça do GitHub por
um equivalente local e mantém **o mesmo fluxo GitOps**:

| Produção (GitHub) | Laboratório local | Como |
| :--- | :--- | :--- |
| Repositórios GitHub | **Gitea** (`localhost:3001`) | container `gitea/gitea` |
| GitHub Actions | **Gitea Actions + act_runner** | mesma sintaxe de workflow, roda em container |
| GHCR | **registry:2** (`localhost:5001`) | os nós do kind mapeiam `localhost:5001` → registry |
| GitHub App (token) | usuário/senha do Gitea em *secret* | secret `GITOPS_PASSWORD` |
| ArgoCD, Helm, ESO, Envoy, OTel, Prometheus, Tempo | **idênticos** | o mesmo `bootstrap.sh` |

> **Gitea Actions roda workflows do GitHub?** Em grande parte, sim: a sintaxe é
> compatível e ele baixa `actions/checkout` etc. do GitHub. Não é 100%: o que é
> *específico do GitHub* não funciona (GHCR, `create-github-app-token`, OIDC do
> Cosign keyless, cache `type=gha`). Por isso o app-repo traz uma **variante local**
> em [`.gitea/workflows/ci-cd.yml`](./app-repo/.gitea/workflows/ci-cd.yml), com o
> mesmo desenho (test → build/push → atualiza `envs/dev`). O Gitea lê
> `.gitea/workflows/` antes de `.github/workflows/`; no GitHub vale o
> `.github/workflows/ci-cd.yml`.

### Os quatro níveis de teste

| Nível | Comando | O que valida | Precisa de |
| :-: | :--- | :--- | :--- |
| 1 | `local-lab.sh check` | `helm lint`, schemas (kubeconform, com CRDs) e `pytest` | Docker + Helm |
| 2 | `local-lab.sh up` | plataforma completa subindo por GitOps (Gitea → ArgoCD) | + kind, kubectl, ~6 GB RAM |
| 3 | `local-lab.sh pipeline` | **o workflow** rodando no runner e fazendo o deploy | nível 2 |
| 4 | `local-lab.sh promote staging` / `prod` | promoção e o *sync manual* de prod | nível 3 |

**Bash**
```bash
./scripts/local-lab.sh check            # 1. sem cluster
./scripts/local-lab.sh up               # 2. cluster + Gitea + runner + ArgoCD + plataforma
./scripts/local-lab.sh pipeline         # 3. dispara o workflow (ver em http://localhost:3001/gitops/webapp/actions)
curl http://webapp.dev.127.0.0.1.nip.io:18088/version
./scripts/local-lab.sh promote staging  # 4. (tag padrão = a que está em dev)
./scripts/local-lab.sh promote prod
./scripts/local-lab.sh status
./scripts/local-lab.sh down             # limpa tudo
```

**PowerShell** (usa o `bash` do Git for Windows)
```powershell
bash ./scripts/local-lab.sh check
bash ./scripts/local-lab.sh up
bash ./scripts/local-lab.sh pipeline
Invoke-RestMethod http://webapp.dev.127.0.0.1.nip.io:18088/version
bash ./scripts/local-lab.sh promote staging
bash ./scripts/local-lab.sh promote prod
bash ./scripts/local-lab.sh status
bash ./scripts/local-lab.sh down
```

`local-lab.sh ci` é um atalho que faz test → build → push → commit **sem** o runner
(útil quando você só quer ver o ArgoCD reagir).

### E o `act`? ([nektos/act](https://github.com/nektos/act))

O `act` executa workflows do **GitHub** direto na sua máquina, em containers.
Ele é a alternativa quando você não quer subir o Gitea, mas só cobre o que não
depende de serviços do GitHub. Neste módulo, é útil para o job `test`:

```bash
act -W app-repo/.github/workflows/ci-cd.yml -j test      # roda pytest exatamente como no GitHub
act pull_request -W gitops-repo/.github/workflows/validate.yml -j chart
```
Os jobs `build`/`deploy-dev` do workflow real **não** rodam no `act` (precisam de
GHCR, GitHub App e OIDC). Para exercitá-los localmente, use o `pipeline` acima.

> **Validado de ponta a ponta** neste laboratório: subida do zero → workflow no runner
> (test → build → push → commit em `envs/dev`) → ArgoCD → Gateway → app com segredo do ESO →
> promoção staging/prod (com sync manual) → self-heal → métricas no Prometheus e traces no Tempo.

## Passo a passo (com GitHub)

### 1. Crie os dois repositórios no GitHub

> Todos os comandos vêm em **Bash** (Linux, macOS, WSL, Git Bash) e
> **PowerShell** (Windows). A versão só de comandos está no [QUICK-START](./QUICK-START.md).

**Bash**
```bash
export ORG=minha-org                       # repos vazios, sem README inicial
cd curso-k8s/modulo-11-gitops-producao
export LAB=$HOME/gitops-lab && mkdir -p "$LAB"

gh repo create $ORG/webapp      --public
gh repo create $ORG/gitops-repo --public   # público = ArgoCD lê sem credencial
git clone https://github.com/$ORG/webapp.git      "$LAB/webapp"
git clone https://github.com/$ORG/gitops-repo.git "$LAB/gitops-repo"
cp -r app-repo/.    "$LAB/webapp/"
cp -r gitops-repo/. "$LAB/gitops-repo/"
```

**PowerShell**
```powershell
$ORG = "minha-org"
Set-Location curso-k8s\modulo-11-gitops-producao
$LAB = "$HOME\gitops-lab"; New-Item -ItemType Directory -Force $LAB | Out-Null

gh repo create "$ORG/webapp" --public
gh repo create "$ORG/gitops-repo" --public
git clone "https://github.com/$ORG/webapp.git"      "$LAB\webapp"
git clone "https://github.com/$ORG/gitops-repo.git" "$LAB\gitops-repo"
Copy-Item "app-repo\*"    "$LAB\webapp"      -Recurse -Force
Copy-Item "gitops-repo\*" "$LAB\gitops-repo" -Recurse -Force
```
(Repo privado? Veja `GITOPS_REPO_TOKEN` no passo 3.) Daqui em diante,
`$LAB/webapp` e `$LAB/gitops-repo` são seus repos de trabalho.

### 2. Configure o acesso do CI ao gitops-repo (GitHub App)

O workflow precisa **escrever** no gitops-repo. O caminho profissional é um
**GitHub App** (token curto, escopo em um único repo, sem usuário humano atrelado):

1. *Settings → Developer settings → GitHub Apps → New*: permissões
   `Contents: Read & write`, `Pull requests: Read & write`. Desmarque webhook.
2. Gere a **private key (.pem)** e instale o App **somente** no `gitops-repo`.
3. No repo `webapp` (*Settings → Secrets and variables → Actions*):
   - Secret `GITOPS_APP_ID` = App ID
   - Secret `GITOPS_APP_PRIVATE_KEY` = conteúdo do `.pem`
   - Variable `GITOPS_REPO` = `minha-org/gitops-repo`

> Atalho para estudo: um PAT fine-grained em `secrets.GITOPS_TOKEN` e trocar o
> passo `app-token` por `token: ${{ secrets.GITOPS_TOKEN }}`.

Se o pacote do GHCR ficar privado, torne-o público (*Packages → webapp →
Settings*) ou crie `imagePullSecrets` — para o lab, público é o mais simples.

### 3. Bootstrap (o único passo imperativo)

**Bash**
```bash
export GITOPS_REPO_URL=https://github.com/$ORG/gitops-repo.git
# export GITOPS_REPO_TOKEN=ghp_xxx     # somente se o repo for privado (token read-only)
GITOPS_DIR="$LAB/gitops-repo" ./scripts/bootstrap.sh
```

**PowerShell** (usa o `bash` do Git for Windows, não o do WSL)
```powershell
$env:GITOPS_REPO_URL = "https://github.com/$ORG/gitops-repo.git"
# $env:GITOPS_REPO_TOKEN = "ghp_xxx"
$env:GITOPS_DIR = ("$LAB\gitops-repo" -replace '\\','/')
bash ./scripts/bootstrap.sh
```

O script: cria o cluster kind → substitui os placeholders `SEU_ORG` → pausa
para você fazer `git push` do gitops-repo → instala o ArgoCD via Helm →
aplica projetos + root app. **Depois disso, você não roda mais nada à mão.**

Acompanhe o ArgoCD construir a plataforma sozinho (waves):

```bash
kubectl -n argocd get applications -w
```

| Wave | Application | Instala |
| :-: | :--- | :--- |
| −3 | `envoy-gateway`, `external-secrets` | controladores + CRDs (Gateway API, ESO) |
| −1 | `platform-config` | Gateway, EnvoyProxy, ClusterSecretStore, ExternalSecret do Grafana |
| 0 | `tempo`, `otel-collector`, `kube-prometheus-stack` | telemetria |
| 1 | `workloads` | ApplicationSet → `webapp-dev/staging/prod` |

### 4. Publique a primeira versão (o fluxo completo)

**Bash**
```bash
cd "$LAB/webapp" && git add -A && git commit -m "feat: initial webapp" && git push
```
**PowerShell**
```powershell
Set-Location "$LAB\webapp"; git add -A; git commit -m "feat: initial webapp"; git push
```
Em *Actions*, observe: **test → build → scan → sign → deploy-dev**.
Em *gitops-repo* aparece o commit `chore(dev): deploy webapp sha-xxxxxxx`.
No ArgoCD, `webapp-dev` fica `OutOfSync` → `Synced` em ≤ 60 s.

```bash
# Bash
curl http://webapp.dev.127.0.0.1.nip.io:18088/version
curl http://webapp.dev.127.0.0.1.nip.io:18088/secret
```
```powershell
# PowerShell
Invoke-RestMethod http://webapp.dev.127.0.0.1.nip.io:18088/version
Invoke-RestMethod http://webapp.dev.127.0.0.1.nip.io:18088/secret
```
`/version` mostra `sha-xxxxxxx`; `/secret` mostra `api_key_loaded: true` e um
fingerprint — o valor veio do ESO, não do Git.
(`nip.io` resolve `*.127.0.0.1.nip.io` para `127.0.0.1` — sem editar `/etc/hosts`.)

### 5. Promova para staging e produção

*Actions → promote → Run workflow*: `tag=sha-xxxxxxx`, `environment=staging`.
O workflow **verifica a assinatura Cosign** e abre um PR no gitops-repo. Faça o
merge → o ArgoCD aplica. Repita com `prod`:

- o PR exige aprovação do CODEOWNER (configure branch protection);
- `webapp-prod` **não tem auto-sync**: após o merge, um humano clica **SYNC** no ArgoCD.

### 6. Telemetria

- **Grafana** — http://localhost:3000 (`admin` / `change-me-in-lab`; senha vinda do ESO).
  Datasource *Tempo* já provisionado. Métricas: `webapp_http_requests_total`,
  `webapp_http_request_duration_seconds`, `webapp_build_info{version=...}`.
- Gere carga e veja traces:
  Bash: `for i in $(seq 200); do curl -s webapp.dev.127.0.0.1.nip.io:18088/work >/dev/null; done`
  · PowerShell: `1..200 | % { Invoke-RestMethod http://webapp.dev.127.0.0.1.nip.io:18088/work | Out-Null }`
  → Grafana → Explore → Tempo → `{ resource.service.name = "webapp" }`.
- Dica: crie um painel com `webapp_build_info` para ver **qual versão roda em cada ambiente**
  e correlacione picos de latência com o instante de cada deploy.

## Exercícios de fixação

1. **Self-heal.** `kubectl -n webapp-dev scale deploy/webapp --replicas=5`. O ArgoCD reverte em segundos: o Git manda, não o `kubectl`.
2. **Rollback = `git revert`.** Reverta o commit de deploy em `envs/dev`. Sem `helm rollback`, sem `kubectl rollout undo`. O histórico do Git é o histórico de deploys.
3. **Rotação de segredo.** Mude `/webapp/dev/api-key` no `ClusterSecretStore` (fake), faça push, e observe o `fingerprint` de `/secret` mudar após o refresh do ESO (reinicie o pod para reler o env).
4. **Imagem não assinada.** Rode `promote` com uma tag que você fez push manualmente: o passo Cosign falha. Guard-rail funcionando.
5. **Novo ambiente.** Copie `envs/staging` para `envs/qa`, adicione `qa` no ApplicationSet. Um PR, um ambiente completo.
6. **Tráfego bloqueado.** Remova o label `gateway-access` do namespace `webapp-dev`: o `HTTPRoute` deixa de ser aceito (`kubectl get httproute -A`). É assim que a plataforma controla quem publica no Gateway.

## Troubleshooting

| Sintoma | Causa provável | Ação |
| :--- | :--- | :--- |
| `platform-config` em `Degraded` no começo | CRDs ainda não existem | Normal; o `retry` resolve. Confira `kubectl -n argocd get app`. |
| `envoy-gateway` erro ao baixar chart | Secret OCI ausente | `kubectl apply -f gitops-repo/bootstrap/02-oci-repo.yaml` |
| `webapp-dev` `ImagePullBackOff` | Pacote GHCR privado ou `SEU_ORG` não substituído | Torne o pacote público; `grep -r SEU_ORG gitops-repo` (PowerShell: `Select-String -Path gitops-repo\* -Pattern SEU_ORG -Recurse`) |
| `curl` em `nip.io` sem resposta | Porta 18088 ocupada / DNS de rede corporativa bloqueia `nip.io` | Use `curl -H 'Host: webapp.dev.127.0.0.1.nip.io' http://localhost:18088/version` (PowerShell: `Invoke-RestMethod -Headers @{Host='webapp.dev.127.0.0.1.nip.io'} http://localhost:18088/version`) |
| Pod `CreateContainerConfigError` | Secret ainda não sincronizado | `kubectl -n webapp-dev get externalsecret` (deve ser `SecretSynced`) |
| `kubectl get httproute` sem `Accepted` | Namespace sem label `gateway-access=true` | O ApplicationSet aplica; confira `managedNamespaceMetadata` |
| `kind create cluster` falha com *ports are not available* | Algo já usa 8080, 18088 ou 3000 no host (outro serviço, WSL, dev server) | Descubra com `netstat -ano \| findstr :18088` (Windows) ou `lsof -i :18088`, e mude o `hostPort` em `cluster-config.yaml` (e a URL nos comandos) |
| Gateway responde dentro do cluster mas não no host | `externalTrafficPolicy: Local` com o pod do Envoy em outro nó que o mapeado pelo kind | Já corrigido em `platform/config/10-envoy-proxy.yaml` (`Cluster`); mantenha se trocar a config |
| Docker Desktop cai durante o `up` | Pouca memória para a stack completa | Docker → Settings → Resources: ≥ 8 GB; rode `up` de novo (é idempotente) |
| Workflow local não inicia | Runner ainda registrando/baixando `catthehacker/ubuntu` (~1 GB) | `docker logs -f gitea-runner`; a primeira execução é lenta |
| `webapp-prod` `Missing` após `promote prod` | Prod não tem auto-sync | O comando já faz o sync; manualmente: `kubectl -n argocd patch application webapp-prod --type merge -p '{"operation":{"sync":{"syncOptions":["CreateNamespace=true"]}}}'` |
| Push do CI recusado | Branch protection bloqueando o App | Permita o App como *bypass* apenas para `envs/dev` |

## CODEOWNERS: o que é e para que serve

`CODEOWNERS` é um arquivo do GitHub (em `.github/CODEOWNERS`, `docs/` ou na
raiz) que diz **quem é o dono de cada caminho do repositório**. Cada linha é
`padrão  @dono1 @dono2`.

Sozinho, ele só **pede revisão automaticamente**: quando um PR toca um arquivo
coberto, os donos são adicionados como revisores. O poder vem combinado com
*branch protection* (*Settings → Branches → main*):

- ☑ *Require a pull request before merging*
- ☑ *Require review from Code Owners* → o merge fica **bloqueado** até um dono aprovar
- ☑ *Require status checks to pass* → o `validate` do gitops-repo precisa estar verde

Neste módulo o [CODEOWNERS](./gitops-repo/.github/CODEOWNERS) faz a separação
de responsabilidades do GitOps:

| Caminho | Dono | Por quê |
| :--- | :--- | :--- |
| `/envs/prod/` | `release-managers` | O `image.tag` de prod só muda com aprovação de quem responde pela release |
| `/envs/staging/` | `devs` | Time de desenvolvimento promove |
| `/envs/dev/` | *(sem dono)* | Automático: o bot do CI faz push direto (bypass da protection só para esse caminho) |
| `/platform/`, `/charts/`, `/bootstrap/` | `platform-team` | Gateway, ESO, ArgoCD e templates afetam **todos** os ambientes |

Regras úteis:
- **A última regra que casa vence** (ordem importa; regras específicas depois das genéricas).
- Donos podem ser `@usuario`, `@org/time` ou e-mail; o time precisa ter permissão de escrita no repo.
- Um arquivo `CODEOWNERS` com erro de sintaxe é ignorado: confira em *Insights → Code owners* (aba do arquivo mostra erros).
- Ele **não** existe no Gitea/lab local (o Gitea tem *required approvals* em branch protection, mas não CODEOWNERS): por isso `promote` local é commit direto.

Resultado prático: mesmo que o CI (ou uma pessoa) abra um PR para `envs/prod`,
ele **não entra** sem aprovação dos `release-managers`, e ainda exige o sync manual no ArgoCD.
Duas camadas humanas independentes antes de produção.

## Guia das ferramentas

Para cada ferramenta: **o que é**, **o papel neste módulo** e **como usar** no dia a dia.

### Infraestrutura local

**Docker** — executa containers. Empacota a aplicação (Dockerfile) e roda o kind, o Gitea e o runner.
```bash
docker ps                          # containers rodando
docker logs -f gitea-runner        # logs (ex.: ver o workflow rodando)
docker build -t webapp:teste app-repo/ && docker run --rm -p 8000:8000 webapp:teste
```

**kind** (*Kubernetes IN Docker*) — cria clusters Kubernetes usando containers como nós. Ideal para laboratório e CI.
```bash
kind create cluster --config cluster-config.yaml
kind get clusters
kind get nodes --name gitops-prod
kind delete cluster --name gitops-prod
```

**kubectl** — CLI para falar com o cluster.
```bash
kubectl get pods -A                                   # tudo, todos os namespaces
kubectl -n webapp-dev describe pod <pod>              # eventos (por que não sobe?)
kubectl -n webapp-dev logs deploy/webapp -f           # logs
kubectl -n webapp-dev get httproute,externalsecret    # recursos das CRDs
kubectl -n argocd get applications                    # estado do GitOps
```

**Helm** — gerenciador de pacotes/templates do Kubernetes. Um *chart* = templates + `values.yaml`.
Aqui é usado de duas formas: instalar o ArgoCD no bootstrap e, dentro do ArgoCD, renderizar o chart `webapp` e os de plataforma.
```bash
helm lint charts/webapp -f envs/prod/values.yaml       # valida
helm template webapp charts/webapp -f envs/dev/values.yaml   # vê o YAML final (sem instalar)
helm show values grafana/tempo --version 1.24.4        # opções de um chart
```

### Git, CI e supply chain

**Git + GitHub** — o Git é o **banco de dados de estado desejado**; o GitHub hospeda repos, PRs, branch protection e CODEOWNERS.
`git revert <sha> && git push` é o **rollback**.

**GitHub Actions** — automação (CI/CD). Workflows YAML em `.github/workflows/`. Neste módulo: `ci-cd.yml` (test/build/scan/sign/deploy-dev),
`promote.yml` (PR de promoção) e `validate.yml` (lint do gitops-repo).
```bash
gh workflow run promote.yml -f tag=sha-1a2b3c4 -f environment=staging
gh run list --workflow ci-cd.yml
gh run watch                       # acompanha a execução
```

**GHCR** (GitHub Container Registry) — registry de imagens em `ghcr.io/<org>/webapp`. Autentica com o `GITHUB_TOKEN` do próprio workflow.

**GitHub App** — identidade de máquina para o CI escrever no gitops-repo, com escopo em **um repo** e token de ~1 h (melhor que PAT de pessoa).
Usado via `actions/create-github-app-token`.

**Trivy** — scanner de vulnerabilidades em imagens. O pipeline falha se houver HIGH/CRITICAL com correção disponível.
```bash
docker run --rm aquasec/trivy image --severity HIGH,CRITICAL ghcr.io/org/webapp:sha-1a2b3c4
```

**Cosign** (Sigstore) — assina imagens. Modo *keyless*: o GitHub emite uma identidade OIDC de curta duração, sem chaves para guardar.
O `promote.yml` só aceita imagens com assinatura do próprio repositório.
```bash
cosign verify ghcr.io/org/webapp:sha-1a2b3c4 \
  --certificate-identity-regexp '^https://github.com/org/webapp/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

**yq** — edita YAML preservando estrutura. O CI usa para trocar só `image.tag`.
```bash
yq -i '.image.tag = "sha-1a2b3c4"' envs/dev/values.yaml
yq '.image.tag' envs/prod/values.yaml            # ler
```

**kubeconform** — valida manifests contra os schemas do Kubernetes e das CRDs. Pega erros antes do ArgoCD.
```bash
helm template webapp charts/webapp -f envs/dev/values.yaml | kubeconform -strict -summary -ignore-missing-schemas -
```

### GitOps e plataforma

**Argo CD** — controlador GitOps: compara o Git (desejado) com o cluster (real) e reconcilia. Conceitos usados:

| Conceito | Papel aqui |
| :--- | :--- |
| `Application` | um "deploy" (fonte no Git → destino no cluster) |
| **App-of-apps** (`root`) | uma Application que cria as demais; único objeto aplicado à mão |
| **ApplicationSet** | gera uma Application por ambiente (dev/staging/prod) |
| `AppProject` | fronteira de segurança: quais repos e namespaces cada projeto pode usar |
| **Sync waves** (`argocd.argoproj.io/sync-wave`) | ordem: CRDs (−3) → configs (−1) → apps (0/1) |
| `selfHeal` / `prune` | reverte alterações manuais / apaga o que saiu do Git |
| Sync manual | prod exige clicar SYNC (gate humano) |

```bash
# UI: http://localhost:8080
argocd login localhost:8080 --username admin --insecure
argocd app list
argocd app diff webapp-prod                 # o que vai mudar?
argocd app sync webapp-prod                 # aplica (o "clique em SYNC")
argocd app history webapp-dev
```
Sem a CLI, dá para forçar refresh: `kubectl -n argocd annotate app webapp-dev argocd.argoproj.io/refresh=hard --overwrite`.

**Gateway API + Envoy Gateway** — a Gateway API é o padrão sucessor do Ingress
(`GatewayClass` → `Gateway` → `HTTPRoute`). O **Envoy Gateway** é a implementação
usada (o Envoy é o proxy). Divisão de papéis: a **plataforma** dona do `Gateway`
(portas, TLS); cada **time** dono do seu `HTTPRoute`. O `Gateway` só aceita rotas de namespaces com o label `gateway-access=true`.
```bash
kubectl get gatewayclass,gateway -A
kubectl -n webapp-dev get httproute webapp -o yaml   # veja status.parents → Accepted/ResolvedRefs
```

**External Secrets Operator (ESO)** — sincroniza segredos de um cofre externo (AWS SM, GCP SM, Vault, Azure KV…) para `Secret` do Kubernetes.
Peças: `ClusterSecretStore` (como falar com o cofre) e `ExternalSecret` (o que buscar). Nenhum segredo entra no Git.
```bash
kubectl get clustersecretstore                       # deve estar Ready
kubectl -n webapp-dev get externalsecret             # STATUS = SecretSynced
kubectl -n webapp-dev get secret webapp-secrets -o jsonpath='{.data.API_KEY}' | base64 -d
```

### Telemetria

**OpenTelemetry (OTel) + Collector** — padrão aberto para traces/métricas/logs. A app envia **OTLP** (gRPC :4317) ao Collector,
que faz batch/limite de memória e exporta para o backend. Trocar de backend = mudar só o Collector.

**Grafana Tempo** — armazena traces. Consulta no Grafana → *Explore → Tempo* (ex.: `{ resource.service.name = "webapp" }`).

**Prometheus + ServiceMonitor** — Prometheus coleta métricas; o `ServiceMonitor` (CRD do operator) diz *o que* raspar (`/metrics` do Service da app).
```bash
kubectl -n webapp-dev get servicemonitor
# Grafana → Explore → Prometheus:
#   sum(rate(webapp_http_requests_total[1m])) by (route, status)
#   histogram_quantile(0.95, sum(rate(webapp_http_request_duration_seconds_bucket[5m])) by (le, route))
#   webapp_build_info          ← qual versão roda em cada ambiente
```

**Grafana** — visualização unificada (métricas, traces). `http://localhost:3000`; a senha de admin vem do ESO.

### Aplicação e laboratório local

**FastAPI + Uvicorn + pytest** — a API de exemplo (`/version`, `/secret`, `/work`, `/metrics`) e seus testes: `pytest -q` dentro de `app-repo/`.

**Gitea + act_runner** — Git server leve com *Actions* compatível com o GitHub; o runner executa os workflows em containers
(a base é o mesmo motor do `act`). Usados só no [laboratório local](#testando-localmente-sem-github).

**nektos/act** — roda workflows do GitHub localmente (ver [seção acima](#e-o-act-nektosact)).

## Levando para produção

O que mudar (e **só** isso) ao sair do kind:

| Área | Lab | Produção |
| :--- | :--- | :--- |
| Cluster | kind | EKS/GKE/AKS/on-prem; rode `CREATE_KIND=false ./scripts/bootstrap.sh` (PowerShell: `$env:CREATE_KIND="false"; bash ./scripts/bootstrap.sh`) |
| Exposição | NodePort 30800 | Em `config/10-envoy-proxy.yaml`: `type: LoadBalancer`, remova o patch de nodePort. DNS real via **external-dns**. |
| TLS | HTTP | **cert-manager** + listener `443` com `certificateRefs` no `Gateway`; redirecionamento 80→443 |
| Segredos | `fake` provider | Troque `platform/config/20-secret-store.yaml` (exemplos abaixo). Autentique via IRSA/Workload Identity — sem chaves estáticas. |
| ArgoCD | 1 réplica, sem SSO | HA (`redis-ha`, réplicas ≥ 2), SSO/OIDC + RBAC por grupo, webhook do GitHub (sync em segundos), notificações (Slack) |
| Telemetria | Tempo local, retenção 6 h | Tempo/Mimir/Loki distribuídos com object storage (módulos 04, 06), Alertmanager + alertas de SLO, amostragem de traces baixa em prod |
| Supply chain | Cosign na promoção | Adicione **Kyverno/Connaisseur** no cluster para rejeitar imagens não assinadas na admissão; pin de actions por SHA |
| Multi-cluster | 1 cluster | Adicione `destination.server` de outros clusters no generator do ApplicationSet (`cluster`/`git` generators) |
| Backups | — | Velero para PVCs; o Git já é o backup do estado declarativo |

### Exemplos de `ClusterSecretStore`

```yaml
# AWS Secrets Manager (EKS + IRSA)
spec:
  provider:
    aws:
      service: SecretsManager
      region: sa-east-1
      auth:
        jwt:
          serviceAccountRef: { name: external-secrets, namespace: external-secrets }
---
# GCP Secret Manager (GKE + Workload Identity)
spec:
  provider:
    gcpsm:
      projectID: meu-projeto
---
# HashiCorp Vault (auth Kubernetes)
spec:
  provider:
    vault:
      server: https://vault.exemplo.com
      path: secret
      version: v2
      auth:
        kubernetes: { mountPath: kubernetes, role: external-secrets }
```
Consulte a [documentação do ESO](https://external-secrets.io/latest/provider/aws-secrets-manager/) para o RBAC/IAM de cada provider.

### Alternativa ao "CI escreve no Git"

O **Argo CD Image Updater** observa o registry e faz o commit de `image.tag`
sozinho. Vantagem: menos peças no CI. Desvantagem: a regra de promoção fica
implícita fora do pipeline. Este módulo usa o workflow explícito por ser
mais auditável e por casar com a promoção por PR.

## Limpeza

```bash
./scripts/teardown.sh                        # Bash
```
```powershell
kind delete cluster --name gitops-prod          # PowerShell
```

## Resumo do que você aprendeu

- Modelo pull-based: o cluster busca o estado; o CI não tem credencial de cluster.
- Separar **código** de **configuração**, e a versão da imagem como *dado* em `values.yaml`.
- Promoção segura: assinatura, PR, CODEOWNERS, sync manual em prod.
- Segredos fora do Git com ESO; publicação com Gateway API; observabilidade via OTLP + Prometheus.
- Reconciliação contínua (self-heal) e rollback por `git revert`.
