#!/usr/bin/env -S make --file

include ./.env

SHELL := /usr/bin/env bash
.SHELLFLAGS := -o errexit -o errtrace -o nounset -o pipefail -c
MAKEFLAGS += --warn-undefined-variables

# Taken from https://www.client9.com/self-documenting-makefiles/
help : ## Print this help
	@awk -F ':|##' '/^[^\t].+?:.*?##/ {\
		printf "\033[36m%-30s\033[0m %s\n", $$1, $$NF \
	}' $(MAKEFILE_LIST)
.PHONY : help
.DEFAULT_GOAL := help

rescan-disks : ## Scan for additional hard disks without restarting the virtual machine
	sudo rescan-scsi-bus.sh
.PHONY : rescan-disks

network-interfaces : ## List network interfaces
	ip link
.PHONY : network-interfaces

password : ## Generate a password
	openssl rand -base64 32
.PHONY : password

monit : ## Print Monit status and summary
	@echo Syntax-Check the Control File
	sudo monit -t
	@echo Status
	sudo monit status
	@echo Summary
	sudo monit summary
.PHONY : monit

crontab : ## List user's and root's contab
	crontab -l
	sudo crontab -u root -l
.PHONY : crontab

ansible-config : ## Dump Ansible config
	ansible-config dump
	ansible-config view
.PHONY : ansible-config

# Lint Ansible playbook without style rules
# ansible-lint \
# 	--config-file ./.ansible-lint \
# 	--skip-list "$$(echo $$(ansible-lint -L | awk -F':' '{print $$1}' | grep '^[^ ]') | tr ' ' ',')" \
# 	./setup.yaml
lint-ansible : ## Lint Ansible
	ansible-lint \
		--config-file ./.ansible-lint \
		./setup.yaml
.PHONY : lint-ansible

fix-ansible : ## Fix Ansible linting violations
	ansible-lint \
		--config-file ./.ansible-lint \
		--fix \
		./setup.yaml
.PHONY : fix-ansible

syntax-ansible : ## Syntax-check Ansible playbook
	./ansible-playbook.sh \
		--syntax-check \
		./setup.yaml
.PHONY : syntax-ansible

dry-run-ansible : ## Dry-run Ansible playbook
	./ansible-playbook.sh \
		--check \
		./setup.yaml
.PHONY : dry-run-ansible-run

validate-vector : ## Validate Vector configuration
	sudo vector validate \
		/etc/vector/vector.yaml
.PHONY : validate-vector

syntax-monit : ## Syntax-check Monit control file
	sudo monit \
		-t \
		-c /etc/monit/monitrc
.PHONY : syntax-monit

check-msmtp : ## Check MSMTP configuration
	msmtp --serverinfo
.PHONY : check-msmtp

check : lint-ansible syntax-ansible validate-vector syntax-monit check-msmtp ## Lint, syntax-check, and validate config files
.PHONY : check
