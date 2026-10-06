#!/bin/bash
set -e

echo "=== Configuração do GitOps com ArgoCD e Descoberta Automática ==="

# Solicita interativamente os dados da organização e do token
read -p "Informe o nome da Organização do GitHub (ex: minha-empresa): " GITHUB_ORG

read -sp "Informe o seu GitHub Personal Access Token (PAT): " GITHUB_TOKEN
echo ""

read -p "Informe o seu usuário do GitHub (dono do PAT; usado no GHCR e no git write-back): " GITHUB_USER

read -p "Informe a tag/tópico do GitHub para filtro [padrão: gitops-app]: " GITHUB_TOPIC_FILTER
GITHUB_TOPIC_FILTER=${GITHUB_TOPIC_FILTER:-gitops-app}

# Bitwarden Secrets Manager (via External Secrets Operator).
# Os UUIDs não são secretos: preencha uma vez aqui (ou exporte antes de rodar).
# Só o access token da machine account é pedido a cada execução.
BW_ORGANIZATION_ID="${BW_ORGANIZATION_ID:-}"
BW_PROJECT_ID="${BW_PROJECT_ID:-}"

if [[ -z "$BW_ORGANIZATION_ID" ]]; then
    read -p "Informe o ID da Organização do Bitwarden (UUID): " BW_ORGANIZATION_ID
fi
if [[ -z "$BW_PROJECT_ID" ]]; then
    read -p "Informe o ID do Projeto do Bitwarden Secrets Manager (UUID): " BW_PROJECT_ID
fi

read -sp "Informe o Access Token da Machine Account do Bitwarden: " BW_ACCESS_TOKEN
echo ""

# Opção opcional para limpar instalações anteriores se desejar resetar do zero
read -p "Deseja limpar instâncias anteriores do ArgoCD antes de prosseguir? (s/N): " CLEANUP_OLD
if [[ "$CLEANUP_OLD" =~ ^[sS]$ ]]; then
    echo "Limpando recursos antigos do ArgoCD..."
    kubectl delete namespace argocd --ignore-not-found=true
    echo "Aguardando namespace ser totalmente removido..."
    while kubectl get namespace argocd &>/dev/null; do
        sleep 2
    done
    echo "Limpeza concluída."
fi

echo -e "\n=== [1/8] Verificando dependências básicas ==="
if ! command -v kubectl &> /dev/null; then
    echo "Erro: O 'kubectl' não está instalado."
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo "Helm não encontrado. Instalando o Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo "-> Helm já está instalado."
fi

echo -e "\n=== [2/8] Criando namespace para o ArgoCD ==="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo -e "\n=== [3/8] Adicionando repositório Helm do ArgoCD ==="
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo -e "\n=== [4/8] Instalando/Atualizando ArgoCD via Helm ==="
# O comando upgrade --install atualiza se já existir ou instala se não existir
helm upgrade --install argocd argo/argo-cd \
    --namespace argocd \
    --wait \
    --timeout 5m

echo -e "\n=== [5/8] Instalando ArgoCD Image Updater ==="
# GHCR exige nomes de imagem em minúsculas
GITHUB_ORG_LC=$(echo "${GITHUB_ORG}" | tr '[:upper:]' '[:lower:]')

# Credencial do registry (user:token) e do git write-back (username/password)
kubectl create secret generic ghcr-creds -n argocd \
    --from-literal=creds="${GITHUB_USER}:${GITHUB_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic git-creds -n argocd \
    --from-literal=username="${GITHUB_USER}" \
    --from-literal=password="${GITHUB_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -

# Chart 0.x = configuração por annotations (a 1.x migrou para o CRD ImageUpdater)
helm upgrade --install argocd-image-updater argo/argocd-image-updater \
    --namespace argocd \
    --version "<1.0.0" \
    --values - \
    --wait \
    --timeout 5m <<EOF
config:
  applicationsAPIKind: kubernetes
  registries:
  - name: GitHub Container Registry
    prefix: ghcr.io
    api_url: https://ghcr.io
    credentials: secret:argocd/ghcr-creds#creds
EOF

echo -e "\n=== [6/8] Instalando External Secrets Operator e conectando ao Bitwarden ==="

# cert-manager: o bitwarden-sdk-server do ESO exige HTTPS
helm repo add jetstack https://charts.jetstack.io
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager --create-namespace \
    --set crds.enabled=true \
    --wait \
    --timeout 5m

kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -

# Certificado self-signed consumido pelo bitwarden-sdk-server (secret bitwarden-tls-certs)
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: bitwarden-selfsigned
  namespace: external-secrets
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: bitwarden-tls-certs
  namespace: external-secrets
spec:
  secretName: bitwarden-tls-certs
  dnsNames:
  - bitwarden-sdk-server.external-secrets.svc.cluster.local
  issuerRef:
    name: bitwarden-selfsigned
    kind: Issuer
EOF
kubectl wait --for=condition=Ready certificate/bitwarden-tls-certs \
    -n external-secrets --timeout=120s

helm upgrade --install external-secrets external-secrets/external-secrets \
    --namespace external-secrets \
    --set installCRDs=true \
    --set bitwarden-sdk-server.enabled=true \
    --wait \
    --timeout 5m

# Access token da machine account (único segredo de bootstrap; fica só no cluster)
kubectl create secret generic bitwarden-access-token -n external-secrets \
    --from-literal=token="${BW_ACCESS_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -

# CA para o ESO confiar no SDK server (cai para tls.crt se ca.crt vier vazio)
BW_CA_BUNDLE=$(kubectl get secret bitwarden-tls-certs -n external-secrets -o jsonpath='{.data.ca\.crt}')
if [[ -z "$BW_CA_BUNDLE" ]]; then
    BW_CA_BUNDLE=$(kubectl get secret bitwarden-tls-certs -n external-secrets -o jsonpath='{.data.tls\.crt}')
fi

kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: bitwarden
spec:
  provider:
    bitwardensecretsmanager:
      apiURL: https://api.bitwarden.com
      identityURL: https://identity.bitwarden.com
      bitwardenServerSDKURL: https://bitwarden-sdk-server.external-secrets.svc.cluster.local:9998
      caBundle: ${BW_CA_BUNDLE}
      organizationID: ${BW_ORGANIZATION_ID}
      projectID: ${BW_PROJECT_ID}
      auth:
        secretRef:
          credentials:
            name: bitwarden-access-token
            namespace: external-secrets
            key: token
EOF
echo "-> ClusterSecretStore 'bitwarden' criado (verifique: kubectl get clustersecretstore bitwarden)"

echo -e "\n=== [7/8] Configurando credencial da Organização e o ApplicationSet ==="

# O kubectl apply atualiza os secrets e o ApplicationSet existentes de forma idempotente
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: github-token-secret
  namespace: argocd
type: Opaque
stringData:
  token: ${GITHUB_TOKEN}
EOF

kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: github-org-autodiscover
  namespace: argocd
spec:
  goTemplate: true
  generators:
  - scmProvider:
      cloneProtocol: https
      github:
        organization: ${GITHUB_ORG}
        tokenRef:
          secretName: github-token-secret
          key: token
      filters:
      - labelMatch: ${GITHUB_TOPIC_FILTER}
  template:
    metadata:
      name: '{{- .repository -}}'
      annotations:
        # Image Updater: imagem esperada em ghcr.io/<org>/<repo>, maior tag semver
        argocd-image-updater.argoproj.io/image-list: 'app=ghcr.io/${GITHUB_ORG_LC}/{{ .repository | lower }}'
        argocd-image-updater.argoproj.io/app.update-strategy: semver
        argocd-image-updater.argoproj.io/write-back-method: git:secret:argocd/git-creds
        argocd-image-updater.argoproj.io/git-branch: '{{ .branch }}'
    spec:
      project: default
      source:
        repoURL: '{{- .url -}}'
        targetRevision: '{{- .branch -}}'
        path: .devops/k8s
      destination:
        server: 'https://kubernetes.default.svc'
        namespace: '{{- .repository -}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
EOF

echo "-> ApplicationSet configurado com sucesso para a organização: ${GITHUB_ORG}"

echo -e "\n=== [8/8] Recuperando credenciais de acesso ==="
sleep 3
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "Gerando...")

echo "--------------------------------------------------------"
echo " 🎉 ArgoCD configurado com sucesso!"
echo "--------------------------------------------------------"
echo "Para acessar a interface web localmente, execute:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "Acesse: https://localhost:8080"
echo "Usuário: admin"
echo "Senha inicial: ${ARGOCD_PASSWORD}"
echo "--------------------------------------------------------"