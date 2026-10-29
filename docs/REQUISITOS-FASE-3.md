# Rastreabilidade dos requisitos — Fase 3

Base: enunciado da Fase 3 disponibilizado pelo responsável.
A matriz relaciona requisitos, implementação e alcance das evidências, sem
atribuir ao repositório de infraestrutura funcionalidades de outros serviços.

| Requisito | Implementação ou comprovação deste repositório | Escopo complementar |
| --- | --- | --- |
| Kubernetes e Terraform | Dois nós Ready nos dois ambientes; Terraform/AWS, states independentes, Calico e Metrics Server comprovados | Bootstrap de produção é etapa explícita pós-Apply, não parte do workflow Terraform |
| Escalabilidade | HPA sintético homolog 1→4→1 e produção 1→2→1; HPA API com confirmação manual identificada | Não equivale a autoscaling de EC2 ou benchmark independente; HTTP do teste sintético de produção teve timeouts |
| CI/CD homolog/produção | CI, Plan salvo e Apply protegido executados no fork nos dois ambientes | Deploy NestJS e execução no repositório oficial não comprovados por esses runs |
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
manual. Em 29/10/2026, as EC2, volumes criptografados, SG e state de produção
foram confirmados na AWS. Após bootstrap autorizado, também foram confirmados
dois nós Ready, Calico, métricas TLS e HPA sintético de produção 1→2→1.
O [checklist atualizado](CI-CD.md#checklist-de-requisitos-fiap) apresenta os estados
implementado, validado e pendente, com fontes por requisito.

[Arquitetura](ARQUITETURA-INFRA.md) · [Evidências](../evidencias/INDEX.md) · [README](../README.md)
