# Comece aqui — Fase 3

1. [README](README.md): apresentação e arquitetura kubeadm em EC2.
2. [Status](docs/STATUS-INFRA.md) e [evidências](evidencias/INDEX.md): resultados datados.
3. [Guia de execução](GUIA-EXECUCAO.md): operação e reprodução em outra conta.
4. [CI/CD](docs/CICD-HOMOLOG.md): homolog/main e aprovações.
5. [Grafana](observability/PLANO-GRAFANA.md): preservar o release existente.

## Fluxo

- Feature/PR: CI sem AWS.
- Push homolog: CI → Plan salvo → aprovação homolog-apply → Apply.
- Push main: equivalente, usando production/production-apply e state separado.
- Produção requer confirmação explícita de capacidade; foi testada localmente.
- O workflow Terraform não faz deploy NestJS nem join do Worker.

Antes de consultas remotas, iniciar Lab, renovar as três credenciais temporárias,
confirmar conta/região e validar host/contexto. O perfil local não autentica runners.
Não aceitar automaticamente host SSH desconhecido.

A demonstração usa PostgreSQL efêmero, não banco gerenciado. Não duplicar
instalações nem repetir provisionamento apenas para obter evidência.

[Documentação](docs/INDEX.md) · [Requisitos](docs/REQUISITOS-FASE-3.md) ·
[Testes locais](docs/VALIDACAO-LOCAL-CICD.md)

Qualquer push homolog/main, inclusive documentação, inicia o fluxo configurado.
Carga, provisionamento e limpeza exigem autorização separada.
