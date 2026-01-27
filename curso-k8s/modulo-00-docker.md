# 🐳 Fundamentos de Docker

> **Pré-requisito essencial**: Este é o alicerce técnico de todo o projeto shift-left. Domine esses conceitos antes de avançar.

---

## 📚 **Índice**

1. [O que é Docker?](#o-que-é-docker)
2. [Conceitos Fundamentais](#conceitos-fundamentais)
3. [Imagens vs Containers](#imagens-vs-containers)
4. [Dockerfile - Criando Imagens](#dockerfile---criando-imagens)
5. [Volumes - Persistência de Dados](#volumes---persistência-de-dados)
6. [Networks - Comunicação Entre Containers](#networks---comunicação-entre-containers)
7. [Comandos Essenciais](#comandos-essenciais)
8. [Boas Práticas](#boas-práticas)
9. [Troubleshooting](#troubleshooting)
10. [Exercícios Práticos](#exercícios-práticos)

---

## 🎯 **O que é Docker?**

### Analogia: Docker como um Container de Navio

Imagine que você precisa transportar produtos de um país para outro:

**SEM Docker (método tradicional):**
- Cada produto precisa de embalagem específica
- Problemas de compatibilidade entre caminhão/navio/trem
- "Funciona no meu caminhão, mas não no navio" 🤷

**COM Docker (containers padronizados):**
- Todos os produtos vão em containers padrão 📦
- Qualquer veículo consegue transportar
- "Se funciona no meu laptop, funciona no servidor" ✅

### Definição Técnica

**Docker** é uma plataforma que permite empacotar aplicações e todas suas dependências em **containers** isolados e portáteis.

```
┌─────────────────────────────────────────┐
│         Aplicação + Dependências        │
│  (código, bibliotecas, configs, etc.)   │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│          Docker Container 📦            │
│  ✅ Isolado    ✅ Portátil             │
│  ✅ Leve       ✅ Reproduzível          │
└─────────────────────────────────────────┘
```

### Por que usar Docker neste projeto?

✅ **Consistência**: DefectDojo, SonarQube e ferramentas rodam igual em todos os ambientes  
✅ **Isolamento**: Cada ferramenta tem seu próprio ambiente sem conflitos  
✅ **Facilidade**: Um comando `docker-compose up` sobe tudo  
✅ **Versionamento**: Imagens com versões fixas garantem estabilidade  
✅ **Portabilidade**: Funciona no laptop do DevOps Jr e no servidor de produção  

---

## 🧩 **Conceitos Fundamentais**

### 1. **Container** 📦

**O que é:** Um processo isolado que roda em cima do kernel do host, mas com seu próprio filesystem, rede e recursos.

**Analogia:** Pense em um apartamento em um prédio:
- O prédio é o sistema operacional (host)
- Cada apartamento é um container
- Apartamentos compartilham a fundação (kernel)
- Mas cada um tem suas próprias paredes, móveis, regras (isolamento)

```
┌───────────────────────────────────────┐
│         Sistema Operacional           │
├───────────────────────────────────────┤
│ Container A │ Container B │ Container C │
│  nginx     │  postgres   │  redis     │
│  porta 80  │  porta 5432 │  porta 6379│
└───────────────────────────────────────┘
```

**Características:**
- ⚡ Leve: compartilha kernel do host
- 🚀 Rápido: inicia em segundos
- 🔒 Isolado: processos não interferem entre si
- 🗑️ Efêmero: pode ser destruído e recriado facilmente

### 2. **Imagem** 💿

**O que é:** Um template read-only usado para criar containers. É como uma "receita" ou "blueprint".

**Analogia:** 
- **Imagem** = Planta de um apartamento (blueprint)
- **Container** = Apartamento construído e habitado

```
┌─────────────────────────────────────┐
│    Imagem: postgres:16-alpine       │
│  (template imutável, read-only)     │
└─────────────────────────────────────┘
                ↓ docker run
┌─────────────────────────────────────┐
│  Container: defectdojo-postgres     │
│   (instância rodando, read-write)   │
└─────────────────────────────────────┘
```

**De onde vêm as imagens?**
1. **Docker Hub**: Repositório público (como GitHub para imagens)
   - `postgres:16-alpine` ← imagem oficial do PostgreSQL
   - `defectdojo/defectdojo-django:latest` ← imagem do DefectDojo

2. **Build local**: Criadas a partir de um `Dockerfile`
   - Nosso `github-runner/Dockerfile` cria imagem customizada

### 3. **Dockerfile** 📝

**O que é:** Arquivo de texto com instruções para construir uma imagem.

**Analogia:** É a receita de bolo. Você segue passo a passo e obtém sempre o mesmo resultado.

```dockerfile
# Exemplo simples
FROM python:3.11-slim          # Base: começa com Python instalado
WORKDIR /app                   # Define diretório de trabalho
COPY requirements.txt .        # Copia arquivo de dependências
RUN pip install -r requirements.txt  # Instala dependências
COPY . .                       # Copia código da aplicação
CMD ["python", "app.py"]       # Comando padrão ao iniciar
```

### 4. **Volume** 💾

**O que é:** Mecanismo de persistência de dados. Dados sobrevivem mesmo quando container é destruído.

**Por que precisa?** Containers são **efêmeros** (temporários). Se você apagar um container, os dados dentro dele são perdidos!

**Analogia:** 
- **Container** = Memória RAM (volátil)
- **Volume** = HD/SSD (persistente)

```
┌──────────────────────────────────────────┐
│        Container PostgreSQL               │
│  /var/lib/postgresql/data ← Volume       │
└──────────────────────────────────────────┘
                ↓
         Dados persistidos
                ↓
┌──────────────────────────────────────────┐
│    Volume: defectdojo_postgres_data      │
│   (sobrevive mesmo se container morrer)  │
└──────────────────────────────────────────┘
```

**Tipos de volumes neste projeto:**

| Volume | Uso | Importância |
|--------|-----|-------------|
| `defectdojo_postgres_data` | Banco de dados do DefectDojo | 🔴 CRÍTICO - Perder = perder todos os achados |
| `sonarqube_data` | Análises e configurações SonarQube | 🔴 CRÍTICO |
| `github_runner_work` | Workspace do runner | 🟡 Pode ser recriado |

### 5. **Network** 🌐

**O que é:** Rede virtual que permite containers se comunicarem.

**Analogia:** Uma rede Wi-Fi privada só para seus containers.

```
┌─────────────────────────────────────────────┐
│       Network: shift-left-network           │
├─────────────────────────────────────────────┤
│                                             │
│  defectdojo-nginx ←→ defectdojo-uwsgi      │
│         ↓                                   │
│  defectdojo-postgres                        │
│                                             │
│  sonarqube ←→ sonarqube-postgres           │
│                                             │
└─────────────────────────────────────────────┘
```

**Por que usar?**
- Containers na mesma rede podem se "ver" pelo nome
- Isolamento de outras redes Docker
- Comunicação segura e performática

---

## 🖼️ **Imagens vs Containers**

Esta é a confusão #1 de quem está aprendendo Docker!

### Comparação Visual

```
┌───────────────────────────────────────────────────────┐
│                    IMAGEM                             │
├───────────────────────────────────────────────────────┤
│ • Read-only (imutável)                                │
│ • Baixada do Docker Hub ou criada via Dockerfile      │
│ • Pode gerar múltiplos containers                     │
│ • Armazenada em camadas (layers)                      │
│                                                       │
│ Comando: docker images                                │
│ Exemplo: postgres:16-alpine                           │
└───────────────────────────────────────────────────────┘
                        ↓
           docker run postgres:16-alpine
                        ↓
┌───────────────────────────────────────────────────────┐
│                   CONTAINER                           │
├───────────────────────────────────────────────────────┤
│ • Read-write (estado mutável)                         │
│ • Instância rodando de uma imagem                     │
│ • Pode ser parado, iniciado, deletado                 │
│ • Tem seu próprio filesystem, rede, processos         │
│                                                       │
│ Comando: docker ps                                    │
│ Exemplo: defectdojo-postgres (container name)         │
└───────────────────────────────────────────────────────┘
```

### Exemplo Prático

```bash
# 1. Listar imagens
docker images
# postgres:16-alpine
# redis:7-alpine
# defectdojo/defectdojo-django:latest

# 2. Criar container a partir da imagem
docker run -d --name meu-postgres postgres:16-alpine

# 3. Listar containers rodando
docker ps
# CONTAINER ID   IMAGE                NAME           STATUS
# abc123         postgres:16-alpine   meu-postgres   Up 2 minutes

# 4. Parar container
docker stop meu-postgres

# 5. Deletar container
docker rm meu-postgres

# 6. A IMAGEM ainda existe!
docker images  # postgres:16-alpine ainda está lá
```

**Regra de ouro:** 
- Imagem = Classe (orientação a objetos)
- Container = Objeto/Instância

---

## 📝 **Dockerfile - Criando Imagens**

### Estrutura de um Dockerfile

```dockerfile
# 1. IMAGEM BASE (sempre começa com FROM)
FROM ubuntu:22.04

# 2. METADADOS (opcional mas recomendado)
LABEL maintainer="devops@empresa.com"
LABEL version="1.0"
LABEL description="Imagem customizada para GitHub Runner"

# 3. VARIÁVEIS DE AMBIENTE
ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNER_VERSION=2.319.1

# 4. INSTALAR DEPENDÊNCIAS
RUN apt-get update && \
    apt-get install -y \
        curl \
        git \
        jq \
        docker.io && \
    rm -rf /var/lib/apt/lists/*

# 5. CRIAR DIRETÓRIOS
WORKDIR /runner
RUN mkdir -p /runner/_work

# 6. COPIAR ARQUIVOS
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 7. EXPOR PORTAS (documentação, não abre porta)
EXPOSE 8080

# 8. VOLUMES (pontos de montagem recomendados)
VOLUME ["/runner/_work"]

# 9. USUÁRIO (boa prática não rodar como root)
USER runner

# 10. COMANDO PADRÃO
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
```

### Instruções Principais

| Instrução | O que faz | Exemplo |
|-----------|-----------|---------|
| `FROM` | Define imagem base | `FROM python:3.11-slim` |
| `RUN` | Executa comando durante build | `RUN apt-get update` |
| `COPY` | Copia arquivos do host para imagem | `COPY app.py /app/` |
| `ADD` | Como COPY mas pode baixar URLs | `ADD https://file.tar.gz /tmp/` |
| `WORKDIR` | Define diretório de trabalho | `WORKDIR /app` |
| `ENV` | Define variável de ambiente | `ENV PORT=8080` |
| `EXPOSE` | Documenta porta usada | `EXPOSE 8080` |
| `VOLUME` | Define ponto de montagem | `VOLUME ["/data"]` |
| `USER` | Define usuário que roda container | `USER appuser` |
| `ENTRYPOINT` | Comando sempre executado | `ENTRYPOINT ["python"]` |
| `CMD` | Argumentos padrão para ENTRYPOINT | `CMD ["app.py"]` |

### Multi-Stage Build (Otimização)

**Problema:** Imagens muito grandes com ferramentas de build desnecessárias em produção.

**Solução:** Construir em etapas, copiar só o necessário.

```dockerfile
# ESTÁGIO 1: BUILD
FROM node:18 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# ESTÁGIO 2: PRODUÇÃO (imagem final menor)
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
CMD ["node", "dist/server.js"]

# Resultado: Imagem final SEM ferramentas de build, muito menor!
```

### Exemplo Real: GitHub Runner (nosso projeto)

```dockerfile
FROM ubuntu:22.04

# Evitar prompts durante instalação
ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependências
RUN apt-get update && apt-get install -y \
    curl git jq docker.io \
    python3 python3-pip \
    nodejs npm \
    openjdk-17-jdk \
    && rm -rf /var/lib/apt/lists/*

# Instalar ferramentas de segurança
RUN pip3 install safety semgrep

# Baixar GitHub Runner
ARG RUNNER_VERSION=2.319.1
RUN mkdir -p /runner && cd /runner && \
    curl -o runner.tar.gz -L \
    https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz && \
    tar xzf runner.tar.gz && rm runner.tar.gz

# Script de inicialização
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /runner

ENTRYPOINT ["/entrypoint.sh"]
```

---

## 💾 **Volumes - Persistência de Dados**

### Por que Volumes?

**Problema:** Containers são **efêmeros**. Dados dentro do container são perdidos quando ele é deletado.

```
❌ SEM VOLUME:
docker run postgres:16-alpine
# Cria banco, insere dados
docker rm container
# 💥 DADOS PERDIDOS!

✅ COM VOLUME:
docker run -v postgres_data:/var/lib/postgresql/data postgres:16-alpine
# Cria banco, insere dados
docker rm container
# ✅ Dados salvos no volume!
docker run -v postgres_data:/var/lib/postgresql/data postgres:16-alpine
# 🎉 Dados restaurados automaticamente!
```

### Tipos de Volumes

#### 1. **Named Volumes** (Recomendado)

Gerenciado pelo Docker, local abstraído.

```yaml
volumes:
  - postgres_data:/var/lib/postgresql/data

# Docker cria e gerencia em:
# Linux: /var/lib/docker/volumes/
# Windows: \\wsl$\docker-desktop-data\data\docker\volumes\
```

#### 2. **Bind Mounts**

Mapeia diretório do host diretamente.

```yaml
volumes:
  - ./local/path:/container/path
  - ./github-runner/entrypoint.sh:/entrypoint.sh:ro  # :ro = read-only
```

**Quando usar cada um?**

| Tipo | Quando usar | Exemplo neste projeto |
|------|-------------|----------------------|
| **Named Volume** | Dados persistentes que Docker gerencia | Bancos de dados, uploads |
| **Bind Mount** | Arquivos de config, desenvolvimento | Scripts, configurações |

#### 3. **tmpfs Mounts** (Memória RAM)

Dados em memória, não persistem.

```bash
docker run --tmpfs /tmp postgres:16-alpine
# /tmp vive apenas enquanto container roda
```

### Volumes no docker-compose.yml

```yaml
services:
  postgres:
    image: postgres:16-alpine
    volumes:
      # Named volume (dados críticos)
      - defectdojo_postgres_data:/var/lib/postgresql/data
      
      # Bind mount (config customizada)
      - ./postgres/custom.conf:/etc/postgresql/postgresql.conf:ro

volumes:
  # Definir named volumes aqui
  defectdojo_postgres_data:
    driver: local
```

### Comandos Úteis para Volumes

```bash
# Listar volumes
docker volume ls

# Inspecionar volume
docker volume inspect defectdojo_postgres_data

# Criar volume manualmente
docker volume create meu_volume

# Remover volume não usado
docker volume rm meu_volume

# Remover TODOS volumes não usados (CUIDADO!)
docker volume prune

# Backup de volume
docker run --rm -v defectdojo_postgres_data:/data \
  -v $(pwd):/backup ubuntu tar czf /backup/backup.tar.gz /data

# Restaurar backup
docker run --rm -v defectdojo_postgres_data:/data \
  -v $(pwd):/backup ubuntu tar xzf /backup/backup.tar.gz -C /
```

---

## 🌐 **Networks - Comunicação Entre Containers**

### Por que Networks?

**Sem network customizada:**
```bash
# Containers isolados, não se "veem"
docker run --name app myapp
docker run --name db postgres
# ❌ app não consegue conectar em db
```

**Com network customizada:**
```bash
docker network create minha-rede
docker run --name app --network minha-rede myapp
docker run --name db --network minha-rede postgres
# ✅ app conecta em db pelo nome: "db:5432"
```

### Tipos de Drivers de Rede

| Driver | Uso | Exemplo |
|--------|-----|---------|
| **bridge** | Padrão, containers na mesma máquina | Nosso projeto (shift-left-network) |
| **host** | Container usa rede do host diretamente | Monitoramento, alta performance |
| **none** | Sem rede | Processamento isolado, segurança |
| **overlay** | Múltiplas máquinas (Docker Swarm) | Cluster, produção distribuída |

### Network no nosso projeto

```yaml
# docker-compose.yml
networks:
  shift-left-network:
    driver: bridge
    name: shift-left-network

services:
  defectdojo-nginx:
    networks:
      - shift-left-network
  
  defectdojo-uwsgi:
    networks:
      - shift-left-network
    # nginx pode acessar: http://defectdojo-uwsgi:8080
```

### DNS Automático

Docker cria DNS automático para containers na mesma rede:

```
Container: defectdojo-nginx
Pode acessar outros containers pelo NOME:

✅ http://defectdojo-uwsgi:8080
✅ http://defectdojo-postgres:5432
✅ http://defectdojo-redis:6379

❌ http://172.18.0.5:8080  (IP muda, não usar!)
```

### Comandos de Network

```bash
# Listar networks
docker network ls

# Inspecionar network (ver quais containers estão conectados)
docker network inspect shift-left-network

# Criar network
docker network create minha-rede

# Conectar container existente a uma rede
docker network connect shift-left-network meu-container

# Desconectar
docker network disconnect shift-left-network meu-container

# Remover network
docker network rm minha-rede

# Limpar networks não usadas
docker network prune
```

---

## 🛠️ **Comandos Essenciais**

### Ciclo de Vida de Containers

```bash
# ========================================
# CRIAR E RODAR
# ========================================

# Modo simples
docker run nginx

# Modo detalhado (detached, com nome, porta)
docker run -d --name meu-nginx -p 8080:80 nginx

# Com volumes e variáveis de ambiente
docker run -d \
  --name meu-postgres \
  -e POSTGRES_PASSWORD=senha123 \
  -v postgres_data:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:16-alpine

# ========================================
# LISTAR
# ========================================

# Containers rodando
docker ps

# Todos (incluindo parados)
docker ps -a

# Apenas IDs
docker ps -q

# ========================================
# PARAR E INICIAR
# ========================================

# Parar (gracefully, envia SIGTERM)
docker stop meu-container

# Parar forçado após 10s
docker stop -t 10 meu-container

# Matar imediatamente (SIGKILL)
docker kill meu-container

# Iniciar container parado
docker start meu-container

# Reiniciar
docker restart meu-container

# ========================================
# LOGS E DEBUGGING
# ========================================

# Ver logs
docker logs meu-container

# Seguir logs em tempo real
docker logs -f meu-container

# Últimas 100 linhas
docker logs --tail 100 meu-container

# Com timestamps
docker logs -t meu-container

# Entrar no container (troubleshooting)
docker exec -it meu-container bash

# Executar comando único
docker exec meu-container ls /app

# Inspecionar detalhes (JSON completo)
docker inspect meu-container

# Ver processos rodando
docker top meu-container

# Estatísticas de uso (CPU, RAM)
docker stats meu-container

# ========================================
# REMOVER
# ========================================

# Remover container parado
docker rm meu-container

# Remover container rodando (força)
docker rm -f meu-container

# Remover todos containers parados
docker container prune

# ========================================
# IMAGENS
# ========================================

# Listar imagens
docker images

# Baixar imagem
docker pull postgres:16-alpine

# Construir imagem a partir de Dockerfile
docker build -t minha-imagem:v1 .

# Construir sem cache
docker build --no-cache -t minha-imagem:v1 .

# Remover imagem
docker rmi postgres:16-alpine

# Remover imagens não usadas
docker image prune

# Ver histórico de layers
docker history postgres:16-alpine

# ========================================
# LIMPEZA GERAL
# ========================================

# Remover tudo não usado (containers, images, networks, volumes)
docker system prune -a --volumes

# Ver uso de espaço
docker system df
```

### Docker Compose (Orquestração)

```bash
# ========================================
# SUBIR SERVIÇOS
# ========================================

# Subir todos os serviços
docker-compose up

# Detached (em background)
docker-compose up -d

# Rebuild imagens antes de subir
docker-compose up --build

# Subir apenas serviços específicos
docker-compose up defectdojo-postgres defectdojo-redis

# ========================================
# PARAR E REMOVER
# ========================================

# Parar todos os serviços
docker-compose stop

# Parar e remover containers
docker-compose down

# Remover incluindo volumes (CUIDADO!)
docker-compose down -v

# Remover incluindo imagens
docker-compose down --rmi all

# ========================================
# LOGS E STATUS
# ========================================

# Ver logs de todos os serviços
docker-compose logs

# Seguir logs
docker-compose logs -f

# Logs de serviço específico
docker-compose logs -f defectdojo-uwsgi

# Ver status dos serviços
docker-compose ps

# ========================================
# EXECUTAR COMANDOS
# ========================================

# Executar comando em serviço
docker-compose exec defectdojo-uwsgi bash

# Executar comando único
docker-compose exec defectdojo-postgres psql -U defectdojo

# Rodar serviço one-off (sem depender de outros)
docker-compose run --rm defectdojo-uwsgi python manage.py migrate

# ========================================
# BUILD E PULL
# ========================================

# Construir imagens
docker-compose build

# Rebuild sem cache
docker-compose build --no-cache

# Baixar imagens
docker-compose pull

# ========================================
# VALIDAÇÃO
# ========================================

# Validar sintaxe do docker-compose.yml
docker-compose config

# Validar silenciosamente
docker-compose config --quiet

# Ver configuração renderizada
docker-compose config --services
```

---

## ✅ **Boas Práticas**

### 1. **Use Imagens Oficiais**

```dockerfile
# ✅ BOM - Imagem oficial, confiável
FROM postgres:16-alpine

# ❌ EVITAR - Imagem de fonte desconhecida
FROM random-user/postgres
```

### 2. **Use Tags Específicas**

```dockerfile
# ✅ BOM - Versão fixa, previsível
FROM postgres:16-alpine

# ⚠️ CUIDADO - Versão muda, pode quebrar
FROM postgres:latest
```

### 3. **Minimize Camadas (Layers)**

```dockerfile
# ❌ RUIM - 3 layers
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y git

# ✅ BOM - 1 layer
RUN apt-get update && \
    apt-get install -y \
        curl \
        git && \
    rm -rf /var/lib/apt/lists/*
```

### 4. **Use .dockerignore**

```
# .dockerignore (como .gitignore)
.git
.env
node_modules
*.log
*.md
Dockerfile*
docker-compose*
```

### 5. **Não rode como root**

```dockerfile
# ✅ BOM - Cria usuário não-privilegiado
RUN useradd -m -u 1000 appuser
USER appuser

# ❌ EVITAR - Roda como root (inseguro)
# (sem declaração de USER)
```

### 6. **Use Multi-Stage Builds**

```dockerfile
# Separar build de produção
FROM node:18 AS builder
WORKDIR /app
COPY . .
RUN npm install && npm run build

FROM node:18-alpine
COPY --from=builder /app/dist /app/dist
CMD ["node", "/app/dist/server.js"]
```

### 7. **Healthchecks**

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:8080/health || exit 1
```

```yaml
# docker-compose.yml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### 8. **Variáveis de Ambiente Sensíveis**

```yaml
# ❌ NUNCA commitar senhas no docker-compose.yml
environment:
  POSTGRES_PASSWORD: senha123

# ✅ BOM - Usar arquivo .env
environment:
  POSTGRES_PASSWORD: ${DB_PASSWORD}

# .env (no .gitignore!)
DB_PASSWORD=senha_segura_aqui
```

### 9. **Limitar Recursos**

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '0.5'      # Máximo 50% de 1 CPU
          memory: 512M     # Máximo 512MB RAM
        reservations:
          cpus: '0.25'     # Mínimo garantido
          memory: 256M
```

### 10. **Ordem de COPY no Dockerfile**

```dockerfile
# ✅ BOM - Aproveita cache do Docker
FROM python:3.11-slim
WORKDIR /app

# 1. Primeiro arquivos que mudam menos (dependências)
COPY requirements.txt .
RUN pip install -r requirements.txt

# 2. Depois código que muda mais
COPY . .

CMD ["python", "app.py"]

# Se mudar apenas app.py, não reinstala dependências!
```

---

## 🔧 **Troubleshooting**

### Problema 1: "Container não inicia"

```bash
# Ver logs do erro
docker logs meu-container

# Inspecionar configuração
docker inspect meu-container

# Tentar rodar interativamente
docker run -it --entrypoint bash minha-imagem
```

### Problema 2: "Porta já em uso"

```bash
# Ver o que está usando a porta
# Windows:
netstat -ano | findstr :8080

# Linux/Mac:
lsof -i :8080

# Mudar porta no docker-compose.yml
ports:
  - "8081:8080"  # host:container
```

### Problema 3: "Sem espaço em disco"

```bash
# Ver uso de espaço
docker system df

# Limpar tudo não usado
docker system prune -a --volumes

# Limpar por tipo
docker container prune  # Containers parados
docker image prune      # Imagens não usadas
docker volume prune     # Volumes órfãos
docker network prune    # Networks não usadas
```

### Problema 4: "Container não acessa internet"

```bash
# Verificar DNS
docker run --rm alpine ping google.com

# Testar com DNS do Google
docker run --dns 8.8.8.8 --rm alpine ping google.com

# Adicionar no docker-compose.yml
services:
  app:
    dns:
      - 8.8.8.8
      - 8.8.4.4
```

### Problema 5: "Containers não se comunicam"

```bash
# Verificar se estão na mesma rede
docker network inspect shift-left-network

# Testar conectividade
docker exec container1 ping container2

# Verificar se portas estão expostas
docker port meu-container
```

### Problema 6: "Permissões de volume"

```bash
# Ver permissões
docker exec meu-container ls -la /data

# Ajustar ownership (se necessário)
docker exec -u root meu-container chown -R 1000:1000 /data
```

### Problema 7: "Build falha com cache antigo"

```bash
# Rebuild sem cache
docker-compose build --no-cache

# Limpar build cache
docker builder prune
```

---

## 🎓 **Exercícios Práticos**

### Nível 1: Básico

#### Exercício 1.1: Primeiro Container
```bash
# 1. Rode nginx
docker run -d --name meu-nginx -p 8080:80 nginx

# 2. Acesse http://localhost:8080
# 3. Veja os logs
docker logs meu-nginx

# 4. Pare e remova
docker stop meu-nginx
docker rm meu-nginx
```

#### Exercício 1.2: Volumes
```bash
# 1. Crie container postgres com volume
docker run -d --name meu-db \
  -e POSTGRES_PASSWORD=senha \
  -v postgres_data:/var/lib/postgresql/data \
  postgres:16-alpine

# 2. Entre no container e crie um banco
docker exec -it meu-db psql -U postgres
# No psql: CREATE DATABASE teste;

# 3. Remova o container
docker rm -f meu-db

# 4. Recrie com mesmo volume
docker run -d --name meu-db-novo \
  -e POSTGRES_PASSWORD=senha \
  -v postgres_data:/var/lib/postgresql/data \
  postgres:16-alpine

# 5. Verifique que banco 'teste' ainda existe
docker exec -it meu-db-novo psql -U postgres -l
```

### Nível 2: Intermediário

#### Exercício 2.1: Criar Dockerfile
```dockerfile
# Crie arquivo: meu-app/Dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app.py .

EXPOSE 5000

CMD ["python", "app.py"]
```

```python
# meu-app/app.py
from flask import Flask
app = Flask(__name__)

@app.route('/')
def hello():
    return 'Hello from Docker!'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

```txt
# meu-app/requirements.txt
flask==3.0.0
```

```bash
# Build
cd meu-app
docker build -t meu-app:v1 .

# Run
docker run -d -p 5000:5000 meu-app:v1

# Teste
curl http://localhost:5000
```

#### Exercício 2.2: Docker Compose Simples
```yaml
# docker-compose-exercicio.yml
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./html:/usr/share/nginx/html:ro
    networks:
      - minha-rede

  app:
    build: ./meu-app
    ports:
      - "5000:5000"
    networks:
      - minha-rede

networks:
  minha-rede:
    driver: bridge
```

```bash
# Subir
docker-compose -f docker-compose-exercicio.yml up -d

# Ver logs
docker-compose -f docker-compose-exercicio.yml logs -f

# Parar
docker-compose -f docker-compose-exercicio.yml down
```

### Nível 3: Avançado

#### Exercício 3.1: Multi-Stage Build
```dockerfile
# Otimize esta imagem Node.js com multi-stage

# Versão inicial (grande)
FROM node:18
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
CMD ["node", "dist/server.js"]

# Sua missão: Criar versão com multi-stage
# Dica: Use node:18 para build e node:18-alpine para produção
```

<details>
<summary>Solução</summary>

```dockerfile
# STAGE 1: Build
FROM node:18 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

# STAGE 2: Production
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
USER node
CMD ["node", "dist/server.js"]
```
</details>

---

## 📊 **Checklist de Conhecimento**

Marque ✅ quando dominar:

### Conceitos
- [ ] Entendo a diferença entre imagem e container
- [ ] Sei quando usar volumes vs bind mounts
- [ ] Compreendo como funciona a rede entre containers
- [ ] Entendo o ciclo de vida de um container
- [ ] Sei explicar por que Docker é útil

### Comandos Básicos
- [ ] `docker run` com opções (-d, -p, -v, --name)
- [ ] `docker ps` e `docker ps -a`
- [ ] `docker logs -f`
- [ ] `docker exec -it container bash`
- [ ] `docker stop/start/restart`
- [ ] `docker rm` e `docker rmi`

### Dockerfile
- [ ] Criar Dockerfile básico
- [ ] Usar FROM, RUN, COPY, CMD
- [ ] Otimizar camadas (layers)
- [ ] Usar multi-stage builds
- [ ] Criar imagem com `docker build`

### Docker Compose
- [ ] Entender estrutura do docker-compose.yml
- [ ] Definir serviços, volumes, networks
- [ ] `docker-compose up/down`
- [ ] `docker-compose logs`
- [ ] `docker-compose exec`

### Troubleshooting
- [ ] Diagnosticar por que container não inicia
- [ ] Resolver conflitos de porta
- [ ] Limpar recursos não usados
- [ ] Acessar logs de container
- [ ] Fazer backup de volumes

### Boas Práticas
- [ ] Usar tags específicas de imagem
- [ ] Criar .dockerignore
- [ ] Não commitar senhas
- [ ] Usar healthchecks
- [ ] Limitar recursos
- [ ] Não rodar como root

---

## 🎯 **Próximos Passos**

Agora que dominou Docker, avance para:

1. **[02-DOCKER-COMPOSE.md](./02-DOCKER-COMPOSE.md)** - Orquestração de múltiplos containers
2. **[03-DEFECTDOJO.md](./03-DEFECTDOJO.md)** - Aplicar conhecimento em DefectDojo
3. **[10-GITHUB-RUNNER.md](./10-GITHUB-RUNNER.md)** - Entender Dockerfile do runner

---

## 📚 **Recursos Adicionais**

### Documentação Oficial
- [Docker Docs](https://docs.docker.com/)
- [Docker Hub](https://hub.docker.com/)
- [Dockerfile Reference](https://docs.docker.com/engine/reference/builder/)
- [Compose File Reference](https://docs.docker.com/compose/compose-file/)

### Prática
- [Play with Docker](https://labs.play-with-docker.com/) - Ambiente online gratuito
- [Docker Samples](https://github.com/docker/awesome-compose) - Exemplos prontos

### Aprofundamento
- [Docker Deep Dive](https://www.goodreads.com/book/show/36411996-docker-deep-dive) - Livro
- [Docker Security Best Practices](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)

---

## 💡 **Dica Final**

> "Docker é como LEGO: peças padronizadas que se encaixam perfeitamente. Domine os blocos básicos (containers, images, volumes, networks) e você conseguirá construir qualquer arquitetura."

**Próxima etapa:** Pratique! Quebre coisas, reconstrua, experimente. Docker permite isso sem medo! 🚀

---

**Última atualização:** Janeiro 2026  
**Autor:** Shift-Left DevOps Team  
**Versão:** 1.0
