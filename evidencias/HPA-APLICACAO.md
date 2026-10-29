# Evidência de HPA da aplicação

## Configuração e consulta registrada

Fonte: [resultado da implantação](tc3-deploy-resultado-local.json),
coletado em 2026-10-28T00:34:18.219Z.

| Campo | Valor registrado |
| --- | --- |
| Namespace | oficina-tc3 |
| Deployment | oficina-api |
| Réplicas mínima/máxima | 1 / 2 |
| CPU alvo | 70% do request |
| CPU observada na consulta sem carga | 7% |
| Réplicas disponíveis na consulta | 1 |
| AbleToScale / ScalingActive | true / true |
| Carga artificial nessa consulta | false |

A consulta comprova configuração, leitura de métricas e disponibilidade naquele
instante. Não comprova, isoladamente, scale-up da API.

## Teste da API — confirmação manual

O responsável confirmou:

- Escala de 1 para 2 Pods.
- 9.986 respostas HTTP bem-sucedidas.
- Zero erros.
- Gerador de carga executado dentro do Pod.

Não há saída bruta ou captura correspondente desse teste no catálogo.
Os valores são mantidos como confirmação manual, sem convertê-los em uma coleta
automatizada. Duração, concorrência, taxa e percentis não foram fornecidos e não
devem ser inferidos.

Gerador e workload compartilham recursos. O consumo do gerador pode contribuir
para a métrica utilizada pelo HPA. O teste demonstra o cenário descrito,
**não constitui benchmark independente** e não estabelece SLO de performance.

## Laboratório sintético — evidência distinta

O [registro Kubernetes/HPA](2026-10-27-kubernetes-hpa.txt) demonstra o workload
cpu-demo no namespace hpa-lab, alvo 50% CPU, limite de 1–4 réplicas e eventos de
escala 1→4→1. Esse workload não utiliza a aplicação ou banco compartilhado.

Não combinar o limite de quatro réplicas do laboratório com o limite de duas da
API, nem atribuir os 9.986 HTTP ao teste sintético.

[Arquitetura](../docs/ARQUITETURA-INFRA.md) · [Índice](INDEX.md)
