#!/usr/bin/env -S make --file
SELF := $(lastword $(MAKEFILE_LIST))

include ./.env

SHELL := /usr/bin/env bash
.SHELLFLAGS := -o errexit -o errtrace -o nounset -o pipefail -c
MAKEFLAGS += --warn-undefined-variables

COMPOSE_BAKE=true
SERVICE=

dotenv_linter = \
	docker run \
		--rm \
		--user $(id --user):$(id --group) \
		--volume "$(pwd):/mnt" \
		--quiet \
		dotenvlinter/dotenv-linter:4.0.0

# Taken from https://www.client9.com/self-documenting-makefiles/
help : ## Print this help
	@awk -F ':|##' '/^[^\t].+?:.*?##/ {\
		printf "\033[36m%-30s\033[0m %s\n", $$1, $$NF \
	}' $(MAKEFILE_LIST)
.PHONY : help
.DEFAULT_GOAL := help

do : ## Deploy services, that is, assert ./.env file, setup machine, pull images, and (re)create and (re)start services
	$(MAKE) --file="${SELF}" dotenv
	$(MAKE) --file="${SELF}" setup
	$(MAKE) --file="${SELF}" services
.PHONY : do

dotenv : ## Assert that all variables in `./.env.${ENVIRONMENT}.sample` are available in `./.env`
	${dotenv_linter} diff /mnt/.env "/mnt/.env.${ENVIRONMENT}.sample"
.PHONY : dotenv

htpasswd : ## Create file ./nginx/.htpasswd if it does not exist
	if [ -f ./nginx/.htpasswd ] ; then \
		sudo touch ./nginx/.htpasswd && \
		sudo chmod 644 ./nginx/.htpasswd ; \
	fi
.PHONY : htpasswd

user : htpasswd ## Add user `${NAME}` (he/she will have access to restricted areas like staging and the Monit web interface with the correct password), for example, `./docker.mk user NAME=jdoe`
	sudo htpasswd ./nginx/.htpasswd "${NAME}"
.PHONY : user

setup : OPTIONS =
setup : htpasswd ## Setup machine by running `ansible-playbook` with options `${OPTIONS}`, for example, `./docker.mk setup` or `./docker.mk OPTIONS="--start-at-task 'Install Monit'" setup`
	./ansible-playbook.sh \
		./setup.yaml \
		${OPTIONS}
.PHONY : setup

services : ## (Re)create and (re)start services
	docker compose up \
		--no-build \
		--no-deps \
		--pull "always" \
		--force-recreate \
		--renew-anon-volumes \
		--remove-orphans \
		--wait ${SERVICE}
.PHONY : services

symlink : ## Confirm that ./docker-compose.yaml links to the correct ./docker-compose.*.yaml
	if [[ ${ENVIRONMENT} == "staging" ]]; then \
		file="./docker-compose.production.yaml" ; \
	else \
		file="./docker-compose.${ENVIRONMENT}.yaml" ; \
	fi && \
	if [[ ! -L "./docker-compose.yaml" ]] || [[ ! "./docker-compose.yaml" -ef $${file} ]]; then \
	    echo "./docker-compose.yaml does not link to $${file}" ; \
	fi
.PHONY : symlink
