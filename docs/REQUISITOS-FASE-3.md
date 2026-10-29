# Matriz de requisitos — Fase 3

Fonte: enunciado oficial transcrito pelo responsável na conversa.
O PDF docs/requisitos/tech-challenge-fase-3.pdf não está disponível localmente.
Não foram presumidos requisitos além da transcrição.

| Requisito | Situação sustentada/documentação | Responsabilidade |
| --- | --- | --- |
| Kubernetes/Terraform | kubeadm/EC2 demonstrados; states independentes preparados | Infra |
| Escalabilidade | Sintético comprovado; API 1→2 informada pelo responsável | Infra/aplicação |
| CI/CD homolog | Implementado; histórico e declaração de Apply registrados | Infra |
| CI/CD produção | Implementado/testado localmente; sem execução remota nesta etapa | Infra/GitHub |
| Aplicação em Kubernetes | Demo NestJS com PostgreSQL efêmero comprovada | Infra/fork aplicação |
| Deploy automático da aplicação | Terraform workflow não implanta NestJS | Equipe aplicação |
| Banco gerenciado | PostgreSQL emptyDir não atende | Equipe banco |
| Gateway e CPF/Lambda/JWT | Não comprovados por demo interna/HTTP 401 | Autenticação/aplicação |
| CPU/memória Kubernetes | Métricas locais e Cloud comprovadas | Infra |
| Logs/eventos Cloud | Confirmações manuais; leitura API limitada por scope | Infra |
| Latência/healthchecks/uptime | Readiness/Swagger testados; completar visão integrada de API | Aplicação/observabilidade |
| JSON/correlação/traces | Não comprovados integralmente; smoke JSON não prova logs da API estruturados | Aplicação |
| Dashboards/alertas de negócio | Não comprovados neste repositório | Aplicação/observabilidade |
| Diagramas/RFCs/ADRs/modelagem do banco | Infra/ADRs locais; consolidar material do grupo | Todos |
| Quatro repos, PR/proteção e README/deploys | Consolidar links/configuração de cada repo | Todos |
| Vídeo até 15 minutos/PDF único | Segmento individual informado como gravado; consolidar entrega | Todos |
| Acesso soat-architecture | Confirmar em cada repo | Proprietários |

Descrever início automático com aprovação humana, sem alegar deploy totalmente
automático. Produção preparada não equivale a produção provisionada.

[Evidências](../evidencias/INDEX.md) · [README](../README.md)
