# infrastructure

Sobe um cluster Kubernetes do zero em dois ambientes com o mesmo conjunto de comandos:

| Ambiente | Cluster | Como é criado |
|---|---|---|
| `prod` | kubeadm em VMs Proxmox (3 control-planes, 3 workers, proxy, NFS) | Terraform + Ansible |
| `kind` | kind local (1 control-plane + 2 workers) | Ansible chamando a CLI do kind |

Em cima do cluster, os **componentes** (MetalLB, ingress-nginx, ArgoCD, Harbor...) são plugins:
você liga e desliga o que quiser por ambiente, e o mesmo código instala nos dois.

## Uso

Rode no Linux/WSL.

```bash
make bootstrap                    # 1x: kubectl, helm, kind, coleções do Ansible, limite de inotify
make up ENV=kind                  # cluster kind + componentes ligados
make up ENV=prod                  # terraform + kubeadm + componentes
```

Passo a passo e variações:

```bash
make infra   ENV=prod             # só as VMs (Terraform) e o inventory
make cluster ENV=kind|prod        # só o cluster
make addons  ENV=kind|prod        # só os componentes
make addons  ENV=prod ONLY=argocd           # um componente (e suas dependências)
make addons  ENV=prod ONLY=harbor,mongodb
make addons  ENV=prod EXTRA="-e argocd_cleanup=true"   # variáveis extras do Ansible
make select  ENV=kind             # menu para ligar/desligar componentes
make status  ENV=kind             # nós e pods
make destroy ENV=kind             # apaga o cluster (prod: terraform destroy)
make reset   ENV=prod             # kubeadm reset nos nós (pede confirmação)
```

`make help` lista tudo. O `kubeconfig` de cada ambiente fica em `environments/<env>/kubeconfig`
(ignorado pelo Git) e não mexe no seu `~/.kube/config`:
`KUBECONFIG=environments/kind/kubeconfig kubectl get pods -A`.

## Estrutura

```
Makefile                       interface única
environments/<env>/
  inventory.ini                prod: gerado pelo Terraform | kind: localhost
  group_vars/all/main.yml      variáveis do ambiente (domínio, CIDRs, MetalLB, storage...)
  group_vars/all/components.yml  quais componentes estão ligados
terraform/                     VMs do prod (módulo modules/vm + for_each) e geração do inventory
ansible/
  playbooks/                   cluster-prod, cluster-kind, components, bootstrap, reset
  roles/                       infraestrutura: docker, k8s, kubeadm, kind, nfs-server, proxy, credentials
  components/<nome>/           um plugin por diretório (tasks, defaults, templates, files)
  components/catalog.yml       ordem, descrição e dependências dos componentes
examples/                      manifestos de teste (não são aplicados por nada)
scripts/select_components.py   menu do `make select`
```

## Componentes

| Nome | O que instala | Depende de |
|---|---|---|
| `cni` | flannel (só kubeadm; o kind já traz kindnet) | |
| `metallb` | MetalLB + pool de IPs | |
| `ingress_nginx` | ingress-nginx | |
| `storage` | NFS CSI + StorageClass `nfs-csi` (prod) ou nada (kind) | |
| `cert_manager` | cert-manager | |
| `istio` | Istio (base + istiod) e `PeerAuthentication` global; mTLS em `PERMISSIVE` por padrão (`istio_mtls_mode`) | `cert_manager` |
| `monitoring` | kube-prometheus-stack: Prometheus, Alertmanager e Grafana | |
| `loki` | Loki (logs, modo monolítico) | |
| `tempo` | Tempo (traces, modo single binary) | |
| `opentelemetry` | OpenTelemetry Operator + coletor gateway (OTLP) + agente de logs | `cert_manager` |
| `external_secrets` | External Secrets Operator + ClusterSecretStore do Bitwarden | `cert_manager` |
| `argocd` | ArgoCD | |
| `argocd_image_updater` | ArgoCD Image Updater | `argocd` |
| `argocd_appset` | ApplicationSet que descobre os repositórios da organização | `argocd` |
| `harbor` | Harbor | |
| `mongodb` | MongoDB (Bitnami) | |
| `jenkins` | Jenkins | |

Dependências são adicionadas sozinhas: `ONLY=argocd_appset` também instala `argocd`.

### Criar um componente novo

1. `ansible/components/<nome>/tasks/main.yml` (e `defaults/`, `templates/`, `files/` se precisar).
2. Uma entrada em `ansible/components/catalog.yml` (a posição na lista é a ordem de instalação).
3. `<nome>: false` em `environments/*/group_vars/all/components.yml`, ou `make select`.

Um componente só precisa de um kubeconfig (já exportado pelo playbook via `KUBECONFIG`);
use `kubernetes.core.helm` / `kubernetes.core.k8s`. Variáveis por ambiente ficam em
`group_vars/all/main.yml`.

## Observabilidade (Grafana, Prometheus, Loki, Tempo, OpenTelemetry)

Ligue `monitoring`, `loki`, `tempo` e `opentelemetry` (já estão ligados nos dois ambientes).

```
 apps ──OTLP──▶ otel-gateway-collector ──▶ Tempo (traces)
  │                  │                  └─▶ Prometheus (métricas OTLP, remote write)
  │                  └────────────────────▶ Loki (logs OTLP)
  ├─ /q/metrics ◀── Prometheus (ServiceMonitor)
  └─ stdout ◀── otel-agent (DaemonSet, filelog) ──▶ Loki
                         Grafana lê Prometheus, Loki e Tempo (datasources já provisionados)
```

- **Grafana:** `http://grafana.<base_domain>` (kind: `grafana.localtest.me`). Usuário `admin`; a senha é gerada
  uma vez e fica no Secret `grafana-admin` (ou defina `grafana_admin_password`). O `make addons` imprime a senha.
- **Endpoint OTLP para as aplicações:** `http://otel-gateway-collector.observability.svc.cluster.local:4317` (gRPC) ou `:4318` (HTTP).
- **Métricas das aplicações:** crie um `ServiceMonitor` ou `PodMonitor` em qualquer namespace; o Prometheus descobre todos.
- **Datasources:** Loki e Tempo só são criados no Grafana se esses componentes estiverem selecionados. Sem eles,
  o gateway manda o sinal para o exporter `debug` (aparece no log do coletor).
- **Logs → traces:** os logs das aplicações devem conter `traceId=<id>`; o Grafana liga o log ao trace (derived field).
- **Storage:** Prometheus, Loki e Tempo usam PVCs na StorageClass padrão. No prod isso é o NFS (`nfs-csi`), que não é
  recomendado para o Prometheus (locking); prefira outra StorageClass via `monitoring_extra_values`.
- **Kind:** a stack completa pede alguns GB de RAM. Para um kind leve, desligue `loki`/`tempo` em `make select ENV=kind`.

## Segredos

- **Bitwarden**: `external_secrets` pede o access token da machine account (prompt, ou
  `BWS_ACCESS_TOKEN` no ambiente). O PAT do GitHub vem do Bitwarden, ou de `GITHUB_TOKEN` se definido.
  O token só é pedido quando um componente que precisa dele está ligado.
- **MongoDB**: `MONGODB_ROOT_PASSWORD` e `MONGODB_PASSWORD` no ambiente (no kind há senhas de dev).
- **Harbor**: `harbor_admin_password` (padrão `admin`; troque no prod).
- **Terraform**: `terraform/terraform.tfvars` (modelo em `terraform.tfvars.example`, ignorado pelo Git).

## Diferenças entre os ambientes

| | prod | kind |
|---|---|---|
| Domínio | `patrick.dev.br` | `localtest.me` (resolve para 127.0.0.1) |
| Ingress | Service LoadBalancer (MetalLB) | hostPort do nó, mapeado para `80/443` do host |
| Storage | `nfs-csi` | StorageClass `standard` do kind |
| API | `k8s.lan:6443` via nginx do proxy | porta local do kind |

No kind o ArgoCD fica em `http://argocd.localtest.me`. Se as portas 80/443 estiverem ocupadas:
`make cluster ENV=kind EXTRA="-e kind_http_port=8080 -e kind_https_port=8443"`.

## Notas

- O kind precisa de `fs.inotify.max_user_instances >= 512` (o padrão do WSL é 128 e o kubelet morre com
  mais de um cluster). `make bootstrap` configura; o playbook avisa se estiver baixo.
- `kubeadm init/join` são idempotentes. O `kubeadm reset` agora só roda por `make reset`.
- No prod, o kubeconfig baixado aponta para `k8s.lan`: a máquina de controle precisa resolver esse nome
  (pihole do proxy).
- O Terraform foi reorganizado em módulo; os blocos `moved` em `terraform/moved.tf` evitam recriar as VMs
  já existentes. Rode `terraform plan` e confirme que não há `destroy` antes do primeiro `apply`.
