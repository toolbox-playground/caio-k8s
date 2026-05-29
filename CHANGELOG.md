## 0.19.0 (2026-05-29)

### Feat

- update Mimir configuration and add MinIO deployment
- **monitoring**: adiciona carga automática para a ranking-api e atualiza instruções no QUICK-START.md
- **monitoring**: adiciona configurações de intervalo de blocos e envio para o MinIO no ConfigMap do Mimir
- **documentação**: atualiza instruções para uso do chart grafana-community/tempo no QUICK-START.md e values-tempo.yaml
- add Ranking API v2 with Pyroscope SDK for continuous profiling
- **monitoring**: adiciona datasources do Grafana para Loki, Tempo e Pyroscope e atualiza configuração do remoteWrite
- **documentação**: adiciona instruções para recuperar a senha do Grafana no QUICK-START.md
- **documentação**: atualiza o QUICK-START.md com instruções para instalar o Metrics Server e ajustes na sequência de instalação
- **monitoring**: atualiza a imagem do MinIO para a última tag válida antes do arquivamento
- **monitoring**: atualiza versão do Metrics Server e adiciona imagem do nó no cluster
- **monitoring**: atualiza versões de imagens do Kubernetes e do MinIO, Mimir e OTel Collector
- **monitoring**: substitui chart bitnami/minio por manifest Kubernetes e atualiza documentação
- **documentação**: adiciona instruções para Windows no QUICK-START.md do Mimir e ArgoCD
- **documentação**: adiciona instruções para Windows no QUICK-START.md do Mimir e ArgoCD
- **monitoring**: add Grafana datasource for Mimir and create alert rules for Four Golden Signals
- **monitoring**: add Kubernetes resources for Super Mario application
- atualiza UIDs dos datasources Loki e Tempo para garantir consistência nas referências
- atualiza instruções sobre o datasource Loki e limitações do eBPF para profiling Python
- atualiza tags de profiling no SDK Python e corrige UID do datasource Loki nos manifestos
- atualiza instruções para gerar carga, separando comandos para PowerShell e Bash
- atualiza instruções para verificação do DaemonSet no módulo de profiling, separando comandos para PowerShell e Bash
- atualiza manifestos do OTel Collector e adiciona novos recursos de datasource no Grafana
- atualiza instruções do Passo 0.8 para instalação do Blackbox Exporter e remove referência ao Módulo 03
- atualiza instruções do Passo 0.8 para instalação do Blackbox Exporter e adiciona seção de alertas
- atualiza instruções de instalação do Blackbox Exporter para PowerShell e Bash
- **opentelemetry**: add Grafana dashboard for p99 latency by endpoint
- **opentelemetry**: add Helm values for Tempo configuration
- **opentelemetry**: create Kubernetes service for ranking API
- **opentelemetry**: implement OpenTelemetry Collector deployment
- **opentelemetry**: add PodMonitor for OpenTelemetry Collector
- **opentelemetry**: provision Grafana datasource for Tempo
- atualiza guia QUICK-START para refletir mudanças na abordagem de profiling contínuo com SDK e Grafana Alloy
- atualiza consultas de métricas para usar exported_endpoint em vez de endpoint
- adiciona provisionamento do datasource Tempo e Pyroscope no Grafana com suporte a Span Profiles
- adiciona suporte ao PyroscopeSpanProcessor para integração com Grafana Tempo
- atualiza Dockerfile e requirements para Python 3.12 e pyroscope-io 1.0.8
- atualiza Dockerfile para usar Python 3.11 e ajusta instruções no guia de início rápido
- atualiza instruções de verificação do SDK Pyroscope e corrige porta no manifesto do Fortio
- atualiza instruções de stress test e adiciona descrição do manifesto do Fortio
- adiciona manifesto do Pod para o stress test com Fortio
- adiciona configuração do Grafana Pyroscope ao cluster
- reorganiza a configuração do serviço Pyroscope para melhor clareza
- remove argumentos extras de retenção de armazenamento no Pyroscope
- corrige a formatação dos argumentos de retenção de armazenamento no Pyroscope
- add hybrid profiling setup with Pyroscope SDK and Grafana Alloy
- reorganiza e atualiza comentários sobre a configuração do OpenTelemetry
- add Pyroscope SDK integration for continuous profiling in ranking-api v2

### Fix

- corrige URL do serviço ranking-api removendo a porta no comando de carga

## 0.18.0 (2026-05-26)

### Feat

- atualiza consulta no Loki para incluir o exportador OTLP
- corrige formatação das instruções de aplicação das regras de alerta no guia de início rápido
- atualiza expressões de consulta no dashboard de logs para incluir o exportador OTLP
- adiciona regras de alerta de latência p99 no Grafana para a Ranking API
- adiciona dashboard p99 por Endpoint para comparação de latência
- adiciona dashboard p99 por Endpoint para monitoramento da Ranking API
- atualiza métricas de latência no guia de início rápido para refletir mudanças no FastAPIInstrumentor
- atualiza dashboard de latência p99 da Ranking API para o padrão OpenTelemetry
- adiciona dashboard DevOps para análise da aplicação via logs no Grafana
- adiciona monitoramento de segurança com OpenTelemetry e dashboard DevSecOps no Grafana
- adiciona dashboard de latência p99 para a Ranking API no Grafana
- Implement Ranking API with OpenTelemetry instrumentation

## 0.17.0 (2026-05-17)

### Feat

- **opentelemetry**: add module 04 for OpenTelemetry instrumentation

## 0.16.3 (2026-01-29)

### Fix

- corrigir links para o módulo de fundamentos de Docker no README.md
- atualizar seções do README.md para melhor clareza e recursos disponíveis

## 0.16.2 (2026-01-29)

### Fix

- atualizar configuração do cluster Kind e melhorar instruções de acesso

## 0.16.1 (2026-01-29)

### Fix

- corrigir caminhos dos manifestos no README.md

## 0.16.0 (2026-01-29)

### Feat

- adicionar configuração do cluster Kind e atualizar instruções de uso

## 0.15.0 (2026-01-29)

### Feat

- adicionar seção sobre preparação de imagens nos clusters Kind

## 0.14.0 (2026-01-29)

### Feat

- adicionar configuração do NGINX Ingress otimizado e remover arquivos obsoletos

## 0.13.10 (2026-01-29)

### Fix

- corrigir comandos de teste para uso de localhost sem porta

## 0.13.9 (2026-01-29)

### Fix

- atualizar instruções para deploy de aplicações e incluir comandos para carregar imagens

## 0.13.8 (2026-01-29)

### Refactor

- renomear arquivos de configuração para 'kind-nginx.yaml' e ajustar mapeamento de portas

## 0.13.7 (2026-01-29)

### Fix

- atualizar instruções de teste para acessar o Nginx via localhost

## 0.13.6 (2026-01-29)

### Fix

- corrigir comando para acessar o container do Kind e adicionar instruções para carregar imagem nginx:alpine

## 0.13.5 (2026-01-29)

### Fix

- atualizar mapeamento de portas para Ingress Controller de 80/443 para 30080/30443

## 0.13.4 (2026-01-29)

### Fix

- atualizar mapeamento de portas para Ingress Controller no Kind

## 0.13.3 (2026-01-29)

### Fix

- adicionar instruções e configuração para resolver problemas de compatibilidade com Kubernetes v1.35.0

## 0.13.2 (2026-01-29)

### Fix

- remover redirecionamento de erro ao deletar cluster no lab de Ingress

## 0.13.1 (2026-01-29)

### Fix

- corrigir sintaxe de comandos no DaemonSet para evitar problemas de execução

## 0.13.0 (2026-01-29)

### Feat

- adicionar exemplos de deployment e ingress para ambientes DEV, STAGING e PROD

## 0.12.0 (2026-01-29)

### Feat

- adicionar instruções para Linux/macOS em laboratórios de Kubernetes

## 0.11.0 (2026-01-29)

### Feat

- atualizar instruções e comandos para a versão 1.35.0 do Kind

## 0.10.0 (2026-01-29)

### Feat

- atualizar instruções de instalação do Kind para versão 0.31.0

## 0.9.0 (2026-01-29)

### Feat

- adicionar imagem do logo Toolbox ao README.md

## 0.8.0 (2026-01-29)

### Feat

- adicionar comentários explicativos sobre mapeamento de portas no cluster-config.yaml

## 0.7.0 (2026-01-29)

### Feat

- adicionar guia de início rápido e estrutura detalhada do laboratório no README.md

## 0.6.0 (2026-01-29)

### Feat

- atualizar instruções de acesso e configuração do serviço no README.md

## 0.5.0 (2026-01-29)

### Feat

- adicionar .gitignore e atualizar configurações de cluster e serviços no Kubernetes

## 0.4.2 (2026-01-28)

### Refactor

- atualizar configurações de cluster e documentação nos manifests do Kubernetes
- remover seções de networking do arquivo de configuração do cluster

## 0.4.1 (2026-01-28)

### Fix

- adicionar comando de saída após puxar imagem do Super Mario

## 0.4.0 (2026-01-28)

### Feat

- atualizar configuração do cluster e manifestos para o Super Mario, ajustando portas e recursos

## 0.3.0 (2026-01-28)

### Feat

- Refactor deployment to use Super Mario game with port-forwarding

## 0.2.1 (2026-01-27)

### Fix

- corrigir caminho do módulo de Docker no README

## 0.2.0 (2026-01-27)

### Feat

- adicionar guia de referência rápida para Kubernetes

## 0.1.0 (2026-01-27)

### Feat

- add deployment and testing scripts for Kubernetes resilience lab
