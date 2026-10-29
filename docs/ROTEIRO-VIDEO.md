# Roteiro de referência — demonstração individual de 3–4 minutos

A gravação foi informada como concluída pelo responsável. Este roteiro organiza
as evidências finais; não executa carga, Apply ou limpeza.

| Tempo | Tela e fala |
| --- | --- |
| 0:00–0:30 | Arquitetura: Terraform, AWS Academy, duas EC2 t3.medium e kubeadm, sem EKS. |
| 0:30–1:00 | Nós Ready, Calico e Metrics Server; top nodes. |
| 1:00–1:35 | NestJS com digest, PostgreSQL temporário emptyDir e Job schema separado, sem seed; não é RDS. |
| 1:35–2:00 | Swagger 200 por localhost e consulta sem JWT 401; não comprova CPF/Lambda. |
| 2:00–2:30 | HPA API 1→2 e 9.986 HTTP/zero erros conforme registro do responsável. Gerador dentro do Pod; não é benchmark independente. |
| 2:30–3:00 | Grafana CPU/memória e logs recentes no Loki. Não afirmar traces. |
| 3:00–3:35 | Merge homolog → CI → Plan salvo → aprovação humana → Apply; usar evidência do run correto. Produção preparada/testada localmente, sem alegar execução remota. |
| 3:35–3:50 | Encerrar com arquitetura/evidências e responsabilidades integradas do grupo. |

Preferir evidências já capturadas para carga/Apply; não repetir operações ao vivo.
Ocultar tokens, credenciais, tfvars, state, kubeconfig e dados de clientes.
Identificar capturas históricas e resultados informados.
Não executar destroy nem excluir namespaces durante a apresentação.

[Evidências](../evidencias/INDEX.md) · [Acesso local](../GUIA-EXECUCAO.md#acesso-local-ao-swagger)
