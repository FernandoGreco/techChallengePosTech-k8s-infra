# Rastreabilidade dos requisitos — Fase 3

Base: enunciado da Fase 3 disponibilizado pelo responsável.
A matriz relaciona requisitos, implementação e alcance das evidências, sem
atribuir ao repositório de infraestrutura funcionalidades de outros serviços.

| Requisito | Implementação ou comprovação deste repositório | Escopo complementar |
| --- | --- | --- |
| Kubernetes e Terraform | kubeadm/EC2 demonstrados; states independentes | Operação de produção requer configuração/evidência próprias |
| Escalabilidade | HPA sintético observado; HPA API com confirmação manual identificada | Não equivale a autoscaling de EC2 ou benchmark independente |
| CI/CD homolog/produção | Workflow com CI, Plan salvo e aprovação protegida | Execução remota de produção não comprovada pelo catálogo |
| Aplicação em Kubernetes | NestJS e PostgreSQL efêmero demonstrados | Pipeline da aplicação é mantido em seu repositório |
| Banco gerenciado | PostgreSQL emptyDir não atende a esse requisito | Repositório de banco gerenciado |
| Gateway e CPF/Lambda/JWT | Não comprovados por Swagger ou resposta HTTP 401 isolada | Autenticação/Gateway/aplicação |
| CPU/memória Kubernetes | Métricas locais e Cloud comprovadas | Métricas de latência de API dependem de instrumentação |
| Logs/eventos Cloud | Confirmações manuais e métricas de recursos documentadas | JSON/correlação/traces não comprovados integralmente |
| Alertas e dashboards de negócio | Não comprovados pelas evidências de infraestrutura | Indicadores e falhas de processamento de ordens de serviço |
| Arquitetura/RFCs/ADRs/modelagem do banco | Componentes e ADRs de infraestrutura documentados | Diagramas de sequência, RFCs e modelagem/justificativa do banco |
| Quatro repositórios, proteção e deploy | Operação e configuração deste repositório descritas | Conferência dos demais repositórios |
| Entrega acadêmica | Documentação e evidências deste componente | PDF único com links, vídeo até 15 minutos e acesso soat-architecture em cada repositório |

O fluxo inicia automaticamente e mantém aprovação humana antes do Apply.
O catálogo distingue código implementado, consulta registrada e confirmação
manual; produção preparada não é declarada como cluster provisionado.

[Arquitetura](ARQUITETURA-INFRA.md) · [Evidências](../evidencias/INDEX.md) · [README](../README.md)
