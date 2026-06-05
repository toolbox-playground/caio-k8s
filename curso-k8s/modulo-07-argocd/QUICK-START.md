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

> **Método preferido** (ArgoCD CLI — documentado oficialmente desde v2.x):

```bash
# Linux / macOS e Windows (PowerShell) — requer CLI instalada
argocd admin initial-password -n argocd
# Saída: <senha>  (delete this secret after changing password)
```

> **Método alternativo** (kubectl direto, sem CLI):

```bash
# Linux / macOS
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```
```pwsh
# Windows (PowerShell)
kubectl -n argocd get secret argocd-initial-admin-secret `
  -o jsonpath="{.data.password}" | ForEach-Object {
    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_))
  }
```

> Após trocar a senha (Fase 10.1), delete este Secret:
> `kubectl -n argocd delete secret argocd-initial-admin-secret`

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

---

## Fase 9 — Conectar ao GitHub (repositório real) ⭐

> **Cenário**: você quer que o ArgoCD monitore um repositório no **GitHub**
> em vez do Gitea local. Isso é o que você usaria em produção real —
> o Gitea existe neste curso apenas para evitar dependência de internet e conta.
>
> Dois casos: repositório **público** (sem credencial) e **privado** (com Deploy Key ou PAT).

---

### 9.1 — Repositório público no GitHub

Se o seu repositório GitHub for público, o registro é simples:

```bash
argocd repo add https://github.com/<seu-usuario>/<seu-repo>.git
```

Verificar:
```bash
argocd repo list
# CONNECTION STATUS = Successful
```

Para apontar uma Application para o GitHub:
```yaml
# apps/00-root-app.yaml
spec:
  source:
    repoURL: https://github.com/<seu-usuario>/<seu-repo>.git
    targetRevision: main
    path: apps
```

---

### 9.2 — Repositório privado: Personal Access Token (PAT)

O método mais simples para repositórios privados — o GitHub gera um token
que você usa como senha HTTPS.

**Passo 1** — Gere o PAT no GitHub:
> GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token

Permissões necessárias (mínimas):
- `Contents: Read-only`
- `Metadata: Read-only`

**Passo 2** — Registre o repo no ArgoCD com o PAT:

```bash
# Linux / macOS
argocd repo add https://github.com/<seu-usuario>/<seu-repo>.git \
  --username <seu-usuario-github> \
  --password <seu-PAT>
```
```pwsh
# Windows (PowerShell)
argocd repo add https://github.com/<seu-usuario>/<seu-repo>.git `
  --username <seu-usuario-github> `
  --password <seu-PAT>
```

> O ArgoCD armazena as credenciais como Secret no namespace `argocd`.
> O PAT nunca fica em plaintext no seu YAML versionado — apenas o `repoURL`.

---

### 9.3 — Repositório privado: SSH Deploy Key (recomendado em produção)

Deploy Key é uma chave SSH vinculada **apenas** a um repositório específico,
sem acesso ao restante da sua conta. É mais seguro que um PAT com escopo amplo.

**Passo 1** — Gerar o par de chaves:

```bash
# Linux / macOS
ssh-keygen -t ed25519 -f argocd-deploy-key -C "argocd@k8s" -N ""
# Gera: argocd-deploy-key (privada) e argocd-deploy-key.pub (pública)
```
```pwsh
# Windows (PowerShell)
ssh-keygen -t ed25519 -f argocd-deploy-key -C "argocd@k8s" -N '""'
```

**Passo 2** — Registrar a chave pública no GitHub:
> GitHub → seu repositório → Settings → Deploy keys → Add deploy key
> - Title: `argocd-k8s`
> - Key: cole o conteúdo de `argocd-deploy-key.pub`
> - Allow write access: **NÃO** (read-only é suficiente)

**Passo 3** — Registrar a chave privada no ArgoCD:

```bash
# Linux / macOS
argocd repo add git@github.com:<seu-usuario>/<seu-repo>.git \
  --ssh-private-key-path argocd-deploy-key \
  --insecure-ignore-host-key
```
```pwsh
# Windows (PowerShell)
argocd repo add git@github.com:<seu-usuario>/<seu-repo>.git `
  --ssh-private-key-path argocd-deploy-key `
  --insecure-ignore-host-key
```

```bash
argocd repo list
# CONNECTION STATUS = Successful
```

> **Boa prática**: após registrar, delete o arquivo `argocd-deploy-key` local
> (a chave já está no Secret do Kubernetes). Use `kubectl -n argocd get secrets`
> para confirmar que o Secret `repo-<hash>` existe.

---

### 9.4 — Webhook: sync imediato no push (sem esperar 3 minutos)

Por padrão, o ArgoCD faz polling a cada 3 minutos. Com um **webhook** do GitHub,
o sync começa em segundos após o `git push`.

**Passo 1** — Expor o ArgoCD para o GitHub (em ambiente local com kind,
use [ngrok](https://ngrok.com) ou [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)):

```bash
# Exemplo com ngrok (apenas para testes)
ngrok http 8080
# Anote a URL: https://xxxx.ngrok.io
```

**Passo 2** — Configurar o webhook no GitHub:
> GitHub → seu repositório → Settings → Webhooks → Add webhook
> - Payload URL: `https://xxxx.ngrok.io/api/webhook`
> - Content type: `application/json`
> - Secret: (gere um secret forte, ex: `openssl rand -hex 20`)
> - Events: selecione apenas **Push events**

**Passo 3** — Adicionar o secret do webhook no ArgoCD:

```bash
# Linux / macOS
kubectl -n argocd patch secret argocd-secret \
  --type merge \
  -p '{"stringData":{"webhook.github.secret":"<seu-webhook-secret>"}}'
```
```pwsh
# Windows (PowerShell)
kubectl -n argocd patch secret argocd-secret `
  --type merge `
  -p '{"stringData":{"webhook.github.secret":"<seu-webhook-secret>"}}'
```

Após o próximo `git push`, o GitHub notifica o ArgoCD e o sync começa imediatamente.

```bash
# Verificar nos logs do ArgoCD server
kubectl -n argocd logs deployment/argocd-server | grep -i webhook
```

---

## Fase 10 — Segurança: Senhas, RBAC e Proteção da Web UI ⭐

> **Cenário**: em produção, você não quer que qualquer pessoa que acesse
> `http://seu-argocd/` consiga ver ou sincronizar aplicações.
> Você precisa de: senha forte para o admin, usuários com permissões limitadas
> e, opcionalmente, SSO via GitHub OAuth.

---

### 10.1 — Trocar a senha do admin (obrigatório em produção)

A senha inicial gerada pelo Helm é fraca e rotacionada.
Troque para uma senha forte assim que instalar:

```bash
# Gerar hash bcrypt da nova senha (Python já incluso no macOS/Linux)
# Linux / macOS
NEW_PASSWORD="MinhaS3nh@Forte!"
BCRYPT_HASH=$(python3 -c "import bcrypt; print(bcrypt.hashpw(b'$NEW_PASSWORD', bcrypt.gensalt(12)).decode())")

kubectl -n argocd patch secret argocd-secret \
  --type merge \
  -p "{\"stringData\":{\"admin.password\":\"$BCRYPT_HASH\",\"admin.passwordMtime\":\"$(date +%FT%T%Z)\"}}"
```
```pwsh
# Windows (PowerShell) — usando a CLI do argocd (mais simples)
argocd account update-password `
  --current-password "<senha-inicial-do-passo-1.3>" `
  --new-password "MinhaS3nh@Forte!"
```

> **Atenção**: a senha do argocd usa **bcrypt** internamente.
> Sempre use `argocd account update-password` ou a UI — nunca edite o Secret manualmente sem o hash.

---

### 10.2 — Desabilitar o usuário admin (best practice em produção)

Após criar outros usuários ou configurar SSO, desabilite o `admin` genérico:

```bash
# Linux / macOS
kubectl -n argocd patch configmap argocd-cm \
  --type merge \
  -p '{"data":{"accounts.admin":"login"}}'
# Para desabilitar completamente:
kubectl -n argocd patch configmap argocd-cm \
  --type merge \
  -p '{"data":{"admin.enabled":"false"}}'
```
```pwsh
# Windows (PowerShell)
kubectl -n argocd patch configmap argocd-cm `
  --type merge `
  -p '{"data":{"admin.enabled":"false"}}'
```

> Só faça isso **depois** de garantir acesso via outro usuário ou SSO.

---

### 10.3 — Criar usuários locais com permissões específicas

O ArgoCD tem um sistema de usuários locais (sem SSO). Útil para pipelines CI/CD.

**Passo 1** — Criar o usuário no ConfigMap `argocd-cm`:

```yaml
# Patch no argocd-cm
# Cada entrada: accounts.<nome> = <capabilities>
# Capabilities: login (pode logar na UI/CLI) | apiKey (pode gerar tokens)
data:
  accounts.alice: login
  accounts.bob: login, apiKey
  accounts.ci-bot: apiKey
```

```bash
# Aplicar via patch
# Linux / macOS
kubectl -n argocd patch configmap argocd-cm \
  --type merge \
  -p '{"data":{"accounts.alice":"login","accounts.ci-bot":"apiKey"}}'
```
```pwsh
# Windows (PowerShell)
kubectl -n argocd patch configmap argocd-cm `
  --type merge `
  -p '{"data":{"accounts.alice":"login","accounts.ci-bot":"apiKey"}}'
```

**Passo 2** — Definir senha para o novo usuário:

```bash
argocd account update-password \
  --account alice \
  --current-password "<senha-admin>" \
  --new-password "SenhaAlice123!"
```

**Passo 3** — Verificar usuários existentes:

```bash
argocd account list
# NAME     ENABLED  CAPABILITIES
# admin    true     login
# alice    true     login
# ci-bot   true     apiKey
```

---

### 10.4 — RBAC: definir o que cada usuário pode fazer

O RBAC do ArgoCD usa o ConfigMap `argocd-rbac-cm`.
A sintaxe usa políticas no estilo **Casbin**:

```
p, <subject>, <resource>, <action>, <object>
```

Onde:
- **subject**: usuário (`alice`) ou grupo (`role:viewer`)
- **resource**: `applications`, `repositories`, `clusters`, `projects`, `accounts`, etc.
- **action**: `get`, `create`, `update`, `delete`, `sync`, `action`, `*`
- **object**: `<project>/<app>` ou `*`

**Exemplo de política completa**:

```yaml
# kubectl -n argocd edit configmap argocd-rbac-cm
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  # Política padrão para usuários sem role explícita
  policy.default: role:readonly

  policy.csv: |
    # --- Roles reutilizáveis ---

    # Viewer: pode ver tudo, não pode sincronizar
    p, role:viewer, applications, get, */*, allow
    p, role:viewer, repositories, get, *, allow
    p, role:viewer, clusters, get, *, allow

    # Developer: pode sync, não pode deletar apps nem gerenciar clusters
    p, role:developer, applications, get,    */*, allow
    p, role:developer, applications, sync,   */*, allow
    p, role:developer, applications, update, */*, allow
    p, role:developer, repositories, get, *, allow

    # Ops: acesso total (mas não é o admin do sistema)
    p, role:ops, applications, *, */*, allow
    p, role:ops, repositories, *, *, allow
    p, role:ops, clusters,      *, *, allow
    p, role:ops, projects,      *, *, allow

    # --- Vinculação de usuários a roles ---
    g, alice,  role:developer
    g, bob,    role:ops
    g, ci-bot, role:developer
```

```bash
# Aplicar o ConfigMap
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:viewer,    applications, get,    */*, allow
    p, role:developer, applications, get,    */*, allow
    p, role:developer, applications, sync,   */*, allow
    p, role:developer, applications, update, */*, allow
    p, role:ops,       applications, *,      */*, allow
    p, role:ops,       clusters,     *,      *, allow
    g, alice,  role:developer
    g, bob,    role:ops
    g, ci-bot, role:developer
EOF
```

**Testar a política**:

```bash
# Sintaxe: argocd admin settings rbac can <subject> <action> <resource> '<project>/<app>' --namespace argocd

# Verifica se alice pode sincronizar a app "mario"
argocd admin settings rbac can alice sync applications 'default/mario' --namespace argocd
# Esperado: Yes

# Verifica se alice pode deletar apps
argocd admin settings rbac can alice delete applications 'default/mario' --namespace argocd
# Esperado: No

# Verificar via política local (sem precisar do cluster)
argocd admin settings rbac can alice sync applications 'default/mario' --policy-file argocd-rbac-cm.yaml
```

> **Alternativa em runtime**: `argocd account can-i sync applications '*'`
> verifica as permissões do usuário **atualmente logado** na CLI.

---

### 10.5 — SSO com GitHub OAuth (login via conta GitHub)

> Em vez de gerenciar senhas locais, você permite que usuários façam login
> com a conta deles no GitHub — e define roles baseadas em **organizações ou times** do GitHub.

**Passo 1** — Criar o OAuth App no GitHub:
> GitHub → Settings → Developer settings → OAuth Apps → New OAuth App
> - Application name: `ArgoCD`
> - Homepage URL: `https://argocd.seudominio.com` (ou `http://localhost:8080` para testes)
> - Authorization callback URL: `https://argocd.seudominio.com/api/dex/callback`
> - Salve o **Client ID** e gere um **Client Secret**

**Passo 2** — Configurar o Dex (provedor OIDC do ArgoCD) via `values-argocd.yaml`:

```yaml
# install/values-argocd.yaml
configs:
  cm:
    url: http://localhost:8080   # URL pública do ArgoCD
    dex.config: |
      connectors:
        - type: github
          id: github
          name: GitHub
          config:
            clientID: <seu-client-id>
            clientSecret: $dex.github.clientSecret   # referência ao Secret
            redirectURI: http://localhost:8080/api/dex/callback
            orgs:
              - name: <sua-org-github>   # apenas membros desta org podem logar
```

**Passo 3** — Criar o Secret com o client secret:

```bash
kubectl -n argocd create secret generic argocd-github-sso \
  --from-literal=dex.github.clientSecret=<seu-client-secret>

# Referenciar no argocd-secret (patch)
kubectl -n argocd patch secret argocd-secret \
  --type merge \
  -p '{"stringData":{"dex.github.clientSecret":"<seu-client-secret>"}}'
```

**Passo 4** — RBAC baseado em times do GitHub:

```yaml
# argocd-rbac-cm
data:
  policy.csv: |
    # Time "devs" da org "minha-empresa" → role developer
    g, minha-empresa:devs, role:developer

    # Time "sre" da org "minha-empresa" → role ops
    g, minha-empresa:sre, role:ops
```

**Passo 5** — Aplicar e reiniciar o Dex:

```bash
helm upgrade argocd argo/argo-cd \
  --namespace argocd \
  -f install/values-argocd.yaml

# Verificar o Dex
kubectl -n argocd rollout status deployment/argocd-dex-server
```

Após isso, a tela de login do ArgoCD exibirá o botão **"Log in via GitHub"**.

---

### 10.6 — Gerar token para CI/CD (pipeline sem UI)

Pipelines de CI (GitHub Actions, GitLab CI etc.) precisam fazer `argocd sync`
sem usuário interativo. Use um **API token**:

```bash
# Gerar token para o ci-bot (que tem capability apiKey)
argocd account generate-token --account ci-bot
# Saída: eyJhbGci... (guarde — aparece só uma vez!)
```

Use o token no seu pipeline:

```yaml
# .github/workflows/deploy.yml
- name: Sync ArgoCD
  env:
    ARGOCD_TOKEN: ${{ secrets.ARGOCD_TOKEN }}
  run: |
    argocd app sync mario \
      --server argocd.seudominio.com \
      --auth-token $ARGOCD_TOKEN \
      --grpc-web
```

> Armazene o token como **GitHub Actions Secret** (`ARGOCD_TOKEN`),
> nunca em plaintext no repositório.

---

### 10.7 — Protegendo via AppProject: namespace isolation

O ArgoCD usa **AppProjects** para isolar times. Um time não consegue
ver ou alterar os recursos de outro time.

```yaml
# apps/project-team-a.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-a
  namespace: argocd
spec:
  description: "Projeto do Time A (apps de frontend)"

  # Repositórios que este projeto pode usar
  sourceRepos:
    - https://github.com/minha-empresa/frontend.git

  # Namespaces de destino permitidos
  destinations:
    - namespace: team-a-*
      server: https://kubernetes.default.svc

  # Recursos Kubernetes que podem ser criados
  clusterResourceWhitelist: []   # sem acesso a recursos de cluster
  namespaceResourceWhitelist:
    - group: apps
      kind: Deployment
    - group: ""
      kind: Service
    - group: ""
      kind: ConfigMap

  # Roles dentro do projeto
  roles:
    - name: developer
      description: "Desenvolvedores do Time A"
      policies:
        - p, proj:team-a:developer, applications, sync, team-a/*, allow
        - p, proj:team-a:developer, applications, get,  team-a/*, allow
      groups:
        - minha-empresa:team-a-devs   # time do GitHub
```

```bash
kubectl apply -f apps/project-team-a.yaml
```

---

### Resumo de Segurança

| Camada | O que protege | Como configurar |
|--------|--------------|-----------------|
| Senha forte do admin | Acesso inicial | `argocd account update-password` |
| Usuários locais | Pipelines CI/CD sem SSO | `argocd-cm` + `argocd-rbac-cm` |
| RBAC por role | O que cada usuário pode fazer | `policy.csv` no `argocd-rbac-cm` |
| SSO GitHub OAuth | Login corporativo via GitHub | `dex.config` no `argocd-cm` |
| AppProject | Isolamento entre times | `AppProject` YAML |
| Deploy Key SSH | Acesso read-only ao repo | chave por repositório, sem acesso à conta |
| API Token | Pipelines automatizados | `argocd account generate-token` |

---

## Questões de Fixação — Fases 9 e 10

1. **Qual a diferença entre PAT e Deploy Key para conectar o ArgoCD ao GitHub?
   Em que situação você prefere cada um?**

2. **Por que o webhook é mais eficiente que o polling padrão de 3 minutos?
   Qual a limitação do webhook em ambiente local (kind)?**

3. **O que acontece com um usuário que não tem role explícita definida no RBAC?
   Qual configuração controla esse comportamento?**

4. **Qual o risco de deixar o usuário `admin` habilitado em produção?
   Quando é seguro desabilitá-lo?**

5. **Você tem um time de frontend e um de backend no mesmo cluster.
   Como o AppProject impede que o time de frontend delete Deployments do backend?**
