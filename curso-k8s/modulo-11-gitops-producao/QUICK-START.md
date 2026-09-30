# Módulo 11 — Quick Start

Módulo independente: só precisa de Docker, kind, kubectl, helm, git e `gh`.
Explicações completas no [README](./README.md).

Todos os comandos têm versão **Bash** (Linux, macOS, WSL, Git Bash) e
**PowerShell** (Windows). Escolha um e siga até o fim.

> No Windows, o `bootstrap.sh` é executado com o `bash` do **Git for Windows**
> (já vem instalado com o Git). Confirme com `bash --version`. Não use o `bash`
> do WSL para este script: ele não enxerga os binários do Windows
> (`kubectl`, `helm`, `kind`).

## Sem GitHub? Teste tudo localmente

Gitea (Git + Actions) + registry + runner + cluster, sem conta em lugar nenhum.
Detalhes na seção *Testando localmente* do [README](./README.md).

**Bash**
```bash
./scripts/local-lab.sh check      # validações offline (sem cluster)
./scripts/local-lab.sh up         # sobe tudo (primeira vez: vários minutos, baixa imagens)
./scripts/local-lab.sh pipeline   # roda o WORKFLOW no runner e faz o deploy em dev
./scripts/local-lab.sh promote staging
./scripts/local-lab.sh promote prod
./scripts/local-lab.sh status
./scripts/local-lab.sh down
```

**PowerShell**
```powershell
bash ./scripts/local-lab.sh check
bash ./scripts/local-lab.sh up
bash ./scripts/local-lab.sh pipeline
bash ./scripts/local-lab.sh promote staging
bash ./scripts/local-lab.sh promote prod
bash ./scripts/local-lab.sh status
bash ./scripts/local-lab.sh down
```

Gitea: http://localhost:3001 (`gitops` / `gitops-secret`) — acompanhe o workflow em `/gitops/webapp/actions`.

---

## Com GitHub (produção)

## 1. Repositórios

**Bash**
```bash
export ORG=minha-org
cd curso-k8s/modulo-11-gitops-producao
export LAB=$HOME/gitops-lab && mkdir -p "$LAB"

gh repo create $ORG/webapp --public
gh repo create $ORG/gitops-repo --public
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
Copy-Item "app-repo\*"    "$LAB\webapp"       -Recurse -Force
Copy-Item "gitops-repo\*" "$LAB\gitops-repo"  -Recurse -Force
```

## 2. Credenciais do CI (uma vez, pela interface do GitHub)

No repo `webapp` → *Settings → Secrets and variables → Actions*:
secrets `GITOPS_APP_ID` e `GITOPS_APP_PRIVATE_KEY`, variable
`GITOPS_REPO=<ORG>/gitops-repo`. O GitHub App (Contents + Pull requests:
write, instalado só no `gitops-repo`) está explicado no [README §2](./README.md).

Ou por CLI:

**Bash**
```bash
gh variable set GITOPS_REPO --repo $ORG/webapp --body "$ORG/gitops-repo"
gh secret   set GITOPS_APP_ID --repo $ORG/webapp --body "123456"
gh secret   set GITOPS_APP_PRIVATE_KEY --repo $ORG/webapp < caminho/da-chave.pem
```

**PowerShell**
```powershell
gh variable set GITOPS_REPO --repo "$ORG/webapp" --body "$ORG/gitops-repo"
gh secret   set GITOPS_APP_ID --repo "$ORG/webapp" --body "123456"
Get-Content -Raw caminho\da-chave.pem | gh secret set GITOPS_APP_PRIVATE_KEY --repo "$ORG/webapp"
```

## 3. Bootstrap (cria o cluster, instala o ArgoCD, aplica a root app)

O script pausa pedindo o `git push` do gitops-repo (ele troca os placeholders
`SEU_ORG`). Faça o push em **outro terminal** e volte ao script para dar ENTER.

**Bash**
```bash
export GITOPS_REPO_URL=https://github.com/$ORG/gitops-repo.git
# export GITOPS_REPO_TOKEN=ghp_xxx      # somente se o repo for privado
GITOPS_DIR="$LAB/gitops-repo" ./scripts/bootstrap.sh

# em outro terminal, quando solicitado:
cd "$LAB/gitops-repo" && git add -A && git commit -m "chore: configure repo URLs" && git push
```

**PowerShell**
```powershell
$env:GITOPS_REPO_URL = "https://github.com/$ORG/gitops-repo.git"
# $env:GITOPS_REPO_TOKEN = "ghp_xxx"    # somente se o repo for privado
$env:GITOPS_DIR = ("$LAB\gitops-repo" -replace '\\','/')   # Git Bash quer barras normais
bash ./scripts/bootstrap.sh

# em outro terminal, quando solicitado:
Set-Location "$HOME\gitops-lab\gitops-repo"
git add -A; git commit -m "chore: configure repo URLs"; git push
```

Cluster já existente (EKS/GKE/AKS/on-prem)? Antes do script:
`export CREATE_KIND=false` (Bash) ou `$env:CREATE_KIND = "false"` (PowerShell).

## 4. Primeira versão: CI → gitops-repo → ArgoCD

**Bash**
```bash
cd "$LAB/webapp" && git add -A && git commit -m "feat: initial webapp" && git push
```

**PowerShell**
```powershell
Set-Location "$HOME\gitops-lab\webapp"
git add -A; git commit -m "feat: initial webapp"; git push
```

## 5. Verificar

**Bash**
```bash
kubectl -n argocd get applications
kubectl -n webapp-dev get pods,httproute,externalsecret
curl http://webapp.dev.127.0.0.1.nip.io:18088/version
curl http://webapp.dev.127.0.0.1.nip.io:18088/secret

# gerar carga para ver traces no Grafana
for i in $(seq 200); do curl -s http://webapp.dev.127.0.0.1.nip.io:18088/work >/dev/null; done
```

**PowerShell**
```powershell
kubectl -n argocd get applications
kubectl -n webapp-dev get pods,httproute,externalsecret
Invoke-RestMethod http://webapp.dev.127.0.0.1.nip.io:18088/version
Invoke-RestMethod http://webapp.dev.127.0.0.1.nip.io:18088/secret

# gerar carga para ver traces no Grafana
1..200 | ForEach-Object { Invoke-RestMethod http://webapp.dev.127.0.0.1.nip.io:18088/work | Out-Null }
```

| O quê | Onde |
| :--- | :--- |
| ArgoCD | http://localhost:8080 (senha impressa pelo bootstrap) |
| Grafana | http://localhost:3000 — `admin` / `change-me-in-lab` |
| App dev / staging / prod | `http://webapp.<env>.127.0.0.1.nip.io:18088` |

Senha do ArgoCD, se precisar de novo:

**Bash**
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```
**PowerShell**
```powershell
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(
  (kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}')))
```

## 6. Promover para staging e prod

**Bash**
```bash
gh workflow run promote.yml --repo $ORG/webapp -f tag=sha-1a2b3c4 -f environment=staging
```
**PowerShell**
```powershell
gh workflow run promote.yml --repo "$ORG/webapp" -f tag=sha-1a2b3c4 -f environment=staging
```
Depois faça o merge do PR aberto no `gitops-repo`. Para `prod`, o ArgoCD não
sincroniza sozinho: clique em **SYNC** (ou `argocd app sync webapp-prod`).

## 7. Limpeza

**Bash**
```bash
./scripts/teardown.sh
```
**PowerShell**
```powershell
kind delete cluster --name gitops-prod
```
