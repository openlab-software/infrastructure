# Interface única do repositório. Rode no Linux/WSL (precisa de ansible, e para o prod, terraform).
#
#   make help
#   make up ENV=kind                 # cluster kind + componentes do ambiente
#   make up ENV=prod                 # terraform + kubeadm + componentes
#   make addons ENV=prod ONLY=argocd # só alguns componentes (e dependências)
#   make select ENV=kind             # menu para escolher os componentes
SHELL := /bin/bash
.DEFAULT_GOAL := help

ENV     ?= kind
ONLY    ?=
EXTRA   ?=

ROOT        := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
ENV_DIR     := $(ROOT)/environments/$(ENV)
ANSIBLE_DIR := $(ROOT)/ansible
KUBECONFIG_FILE := $(ENV_DIR)/kubeconfig

export ANSIBLE_CONFIG := $(ANSIBLE_DIR)/ansible.cfg

PLAY = cd $(ANSIBLE_DIR) && ansible-playbook -i $(ENV_DIR)/inventory.ini $(EXTRA)

.PHONY: help check-env bootstrap infra cluster addons up select kubeconfig status destroy reset syntax

help: ## Mostra esta ajuda
	@echo "Uso: make <alvo> [ENV=kind|prod] [ONLY=comp1,comp2] [EXTRA=\"-e var=valor\"]"; echo
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'
	@echo; echo "Ambientes: $$(ls $(ROOT)/environments | tr '\n' ' ')"

check-env:
	@test -d "$(ENV_DIR)" || { echo "Ambiente '$(ENV)' não existe. Disponíveis: $$(ls $(ROOT)/environments | tr '\n' ' ')"; exit 1; }

bootstrap: ## Prepara a máquina de controle (docker, kubectl, helm, kind, coleções do Ansible)
	cd $(ANSIBLE_DIR) && ansible-playbook -i localhost, playbooks/bootstrap.yml --ask-become-pass

infra: check-env ## [prod] Cria/atualiza as VMs no Proxmox (Terraform) e gera o inventory
	@test "$(ENV)" = prod || { echo "infra só existe no ambiente prod"; exit 1; }
	terraform -chdir=$(ROOT)/terraform init -input=false
	terraform -chdir=$(ROOT)/terraform apply

cluster: check-env ## Cria o cluster (kind: kind create | prod: kubeadm nas VMs)
	$(PLAY) playbooks/cluster-$(ENV).yml

addons: check-env ## Instala os componentes do ambiente (ONLY=a,b para escolher)
	$(PLAY) playbooks/components.yml $(if $(ONLY),-e components_only=$(ONLY))

up: check-env ## Tudo: [infra no prod] + cluster + componentes
ifeq ($(ENV),prod)
	$(MAKE) infra ENV=prod
endif
	$(MAKE) cluster ENV=$(ENV)
	$(MAKE) addons ENV=$(ENV)

select: check-env ## Menu interativo para ligar/desligar componentes do ambiente
	python3 $(ROOT)/scripts/select_components.py $(ENV)

kubeconfig: check-env ## Mescla o kubeconfig do ambiente no ~/.kube/config (faz backup)
	@test -f "$(KUBECONFIG_FILE)" || { echo "Sem kubeconfig em $(KUBECONFIG_FILE). Crie o cluster antes: make cluster ENV=$(ENV)"; exit 1; }
	@mkdir -p "$$HOME/.kube"; touch "$$HOME/.kube/config"; cp "$$HOME/.kube/config" "$$HOME/.kube/config.bak"
	@KUBECONFIG="$(KUBECONFIG_FILE):$$HOME/.kube/config" kubectl config view --flatten > "$$HOME/.kube/config.new" 		&& mv "$$HOME/.kube/config.new" "$$HOME/.kube/config" && chmod 600 "$$HOME/.kube/config"
	@echo "Mesclado em ~/.kube/config (backup em ~/.kube/config.bak). Contexto atual: $$(kubectl config current-context)"
	@echo "Para usar só este cluster na sessão: export KUBECONFIG=$(KUBECONFIG_FILE)"

status: check-env ## Nós e pods do cluster do ambiente
	KUBECONFIG=$(KUBECONFIG_FILE) kubectl get nodes -o wide
	KUBECONFIG=$(KUBECONFIG_FILE) kubectl get pods -A

destroy: check-env ## Remove o cluster (kind: apaga o cluster | prod: terraform destroy)
ifeq ($(ENV),kind)
	$(PLAY) playbooks/cluster-kind.yml -e kind_state=absent
else
	terraform -chdir=$(ROOT)/terraform destroy
endif

reset: check-env ## [prod] kubeadm reset em todos os nós (pede confirmação)
	@test "$(ENV)" = prod || { echo "reset só existe no ambiente prod (no kind use: make destroy)"; exit 1; }
	$(PLAY) playbooks/cluster-prod-reset.yml

syntax: check-env ## Valida a sintaxe dos playbooks do ambiente
	$(PLAY) playbooks/components.yml --syntax-check
	$(PLAY) playbooks/cluster-$(ENV).yml --syntax-check
