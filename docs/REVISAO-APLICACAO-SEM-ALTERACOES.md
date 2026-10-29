# Integração com aplicação — riscos e limites

> Revisão inicial histórica da aplicação original. A demonstração posterior utilizou o fork com correção Docker OpenSSL e startup sobrescrito. Consulte [arquitetura](ARQUITETURA-INFRA.md).

O ZIP da aplicação é analisado separadamente; **nenhum arquivo da
aplicação foi modificado**.

## Atenção antes de executar no Kubernetes
- O Dockerfile da aplicação fornecida executa comandos Prisma no
  startup (`db push`/seed). Não executar réplicas contra RDS compartilhado
  sem a aprovação do responsável pelo banco e isolamento de homolog.
- `oficina-api:latest` só funciona no cluster se a imagem estiver
  disponível para todos os nodes (registry ou import em cada node).
- Não usar secrets de desenvolvimento com RDS real.
- Instrumentação de API (latência, traces, ordens de serviço) requer
  colaboração do grupo e testes de integração.
- Para provar o HPA de **infraestrutura**, usar apenas o workload
  sintético em `tests/hpa-lab.yaml`, sem banco.
