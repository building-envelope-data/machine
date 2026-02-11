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
		--user $(shell id --user):$(shell id --group) \
		--volume "$(shell pwd):/mnt" \
		--pull "always" \
		--quiet \
		dotenvlinter/dotenv-linter:latest

# Taken from https://www.client9.com/self-documenting-makefiles/
help : ## Print this help
	@awk -F ':|##' '/^[^\t].+?:.*?##/ {\
		printf "\033[36m%-30s\033[0m %s\n", $$1, $$NF \
	}' $(MAKEFILE_LIST)
.PHONY : help
.DEFAULT_GOAL := help

name : ## Print value of variable `NAME`
	@echo ${NAME}
.PHONY : name

dotenv : ## Assert that all variables in `./.env.sample` are available in `./.env`
	${dotenv_linter} diff /mnt/.env "/mnt/.env.${ENVIRONMENT}.sample"
	${dotenv_linter} diff /mnt/.env.development.sample /mnt/.env.production.sample
	${dotenv_linter} diff /mnt/.env.production.buildingenvelopedata.sample /mnt/.env.production.sample
	${dotenv_linter} diff /mnt/.env.production.solarbuildingenvelopes.sample /mnt/.env.production.sample
	${dotenv_linter} diff /mnt/.env.development.buildingenvelopedata.sample /mnt/.env.development.sample
	${dotenv_linter} diff /mnt/.env.development.solarbuildingenvelopes.sample /mnt/.env.development.sample
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
		--skip-tags "skip_in_${ENVIRONMENT}" \
		${OPTIONS}
.PHONY : setup

pull : ## Pull images
	docker compose pull ${SERVICE}
.PHONY : pull

up : ## (Re)create and (re)start services
	docker compose up \
		--force-recreate \
		--renew-anon-volumes \
		--remove-orphans \
		--wait ${SERVICE}
.PHONY : up

deploy : dotenv setup pull up ## Deploy services, that is, assert ./.env file, setup machine, pull images, and (re)create and (re)start services
.PHONY : deploy

logs : ## Follow logs of services, for example, `make logs` for all services or `make logs SERVICE=reverse_proxy` or `make logs SERVICE="logs metrics"`
	docker compose logs \
		--since=1h \
		--follow ${SERVICE}
.PHONY : logs

shell : ## Enter shell in the service `${SERVICE}`
	docker compose up \
		--remove-orphans \
		--wait 
		${SERVICE}
	docker compose exec \
		${SERVICE} \
		bash
.PHONY : shell

machine : ## Enter shell in the `machine` service for debugging and testing, for example by running `./docker.mk setup` or `./tools.mk check` inside entered shell
	docker compose pull \
		machine
	docker compose build \
		--build-arg GROUP_ID=$(shell id --group) \
		--build-arg USER_ID=$(shell id --user) \
		machine
	docker compose run \
		--rm \
		--remove-orphans \
		machine \
		bash
.PHONY : machine

down : ## Stop containers and remove containers, networks, volumes, and images created by `deploy`
	docker compose down \
		--remove-orphans ${SERVICE}
.PHONY : down

list : ## List all containers with health status
	docker compose ps \
		--no-trunc \
		--all ${SERVICE}
.PHONY : list

list-services : ## List all services specified in the docker-compose file (used by Monit)
	docker compose config \
		--services
.PHONY : list-services

# See https://docs.docker.com/config/containers/runmetrics/
docker-stats : ## Show Docker run-time metrics
	docker stats
.PHONY : docker-stats

reload-daemon : ## Reload Docker daemon
	sudo systemctl \
		reload docker
.PHONY : reload-daemon

renew-tls : ## Renew Transport Layer Security (TLS) certificates needed for the `S` in `HTTPS` (used by Cron)
	$(MAKE) --file=./certificates.mk renew
	$(MAKE) --file="${SELF}" deploy
.PHONY : renew-tls

shellcheck = \
	docker run \
		--rm \
		--user $(shell id --user):$(shell id --group) \
		--volume "$(shell pwd):/mnt" \
		--pull "always" \
		--quiet \
		koalaman/shellcheck:latest \
		--enable=all \
		--external-sources

dclint = \
	docker run \
		--rm \
		--tty \
		--user $(shell id --user):$(shell id --group) \
		--volume "$(shell pwd):/app" \
		--pull "always" \
		--quiet \
		zavoloklom/dclint:latest \
		--config /app/.dclintrc

hadolint = \
	docker run \
		--rm \
		--interactive \
		--user $(shell id --user):$(shell id --group) \
		--volume ./.hadolint.yaml:/.config/.hadolint.yaml \
		--pull "always" \
		--quiet \
		hadolint/hadolint:latest \
		hadolint \
		--config /.config/.hadolint.yaml

# docker run \
# 	--workdir / \
# 	--volume ./checkmake.ini:/checkmake.ini \
# 	--volume ./Makefile:/Makefile \
# 	--volume ./Makefile.development:/Makefile.development \
# 	quay.io/checkmake/checkmake \
# 	/Makefile \
# 	/Makefile.development
lint : ## Lint .env files, shell scripts, Docker Compose files, and Dockerfile
	@echo Lint .env Files
	${dotenv_linter} \
		check \
		--recursive \
		--ignore-checks UnorderedKey \
		.
	@echo Lint Shell Scripts
	${shellcheck} ./*.sh
	@echo Lint Docker Compose Files
	${dclint} .
	@echo Lint Dockerfiles
	${hadolint} - < ./Dockerfile.development
.PHONY : lint

fix : ## Fix .env files and Docker Compose linting violations
	@echo Fix .env Files
	${dotenv_linter} \
		fix \
		--no-backup \
		--recursive \
		--ignore-checks UnorderedKey \
		.
	@echo Fix Docker Compose Files
	${dclint} --fix .
.PHONY : fix

format : ## Format shell scripts and Dockerfile
	@echo Format Shell Scripts
	docker run \
		--rm \
		--user $(shell id --user):$(shell id --group) \
		--volume "$(shell pwd):/mnt" \
		--workdir /mnt \
		mvdan/shfmt:latest \
		--write \
		--simplify \
		--indent 2 \
		--case-indent \
		--space-redirects \
		$(shell find . -name "*.sh" -printf "/mnt/%h/%f ")
	@echo Format Dockerfile
	docker run \
		--rm \
		--user $(shell id --user):$(shell id --group) \
		--volume "$(shell pwd):/pwd" \
		--pull "always" \
		--quiet \
		ghcr.io/reteps/dockerfmt:latest \
		--indent 2 \
		--newline \
		--write \
		$(shell find . -name "Dockerfile*" -printf "/pwd/%h/%f ")
.PHONY : format
