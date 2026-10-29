# Comece aqui — Fase 3

1. [README](README.md): objetivo, arquitetura kubeadm em EC2 e tecnologias.
2. [Guia de execução](GUIA-EXECUCAO.md): validação e reprodução em outra conta.
3. [CI/CD](docs/CICD-HOMOLOG.md): homolog/main, states e aprovações.
4. [Grafana Cloud](observability/PLANO-GRAFANA.md): instalação e consultas.
5. [Evidências](evidencias/INDEX.md): resultados datados e alcance da comprovação.

## Fluxo

- Feature/PR: CI sem AWS.
- Push homolog: CI → Plan salvo → aprovação homolog-apply → Apply.
- Push main: equivalente, usando production/production-apply e state separado.
- Produção exige confirmação explícita de capacidade e configuração própria.
- O workflow Terraform não realiza deploy NestJS nem join do Worker.

Antes de consultas remotas, iniciar o Lab, renovar o conjunto de credenciais
temporárias e confirmar conta, região, contexto e identidade do host.
O perfil local não autentica runners. Não aceitar host SSH desconhecido.

A aplicação demonstrada usa PostgreSQL efêmero, não banco gerenciado.
Não duplicar instalações nem repetir provisionamento para produzir evidência.

[Documentação](docs/INDEX.md) · [Requisitos](docs/REQUISITOS-FASE-3.md)

Qualquer push homolog/main, inclusive documental, inicia o fluxo configurado.
Carga, provisionamento e limpeza exigem autorização separada.
