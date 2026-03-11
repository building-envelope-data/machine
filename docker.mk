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

name : ## Print value of variable `NAME`
	@echo ${NAME}
.PHONY : name

dotenv : ## Assert that all variables in `./.env.${ENVIRONMENT}.sample` are available in `./.env`
	${dotenv_linter} diff /mnt/.env "/mnt/.env.${ENVIRONMENT}.sample"
	${dotenv_linter} diff /mnt/.env.development.sample /mnt/.env.production.sample
	${dotenv_linter} diff /mnt/.env.production.buildingenvelopedata.sample /mnt/.env.production.sample
	${dotenv_linter} diff /mnt/.env.production.solarbuildingenvelopes.sample /mnt/.env.production.sample
	${dotenv_linter} diff /mnt/.env.development.buildingenvelopedata.sample /mnt/.env.development.sample
	${dotenv_linter} diff /mnt/.env.development.solarbuildingenvelopes.sample /mnt/.env.development.sample
.PHONY : dotenv

pull : ## Pull images
	docker compose pull ${SERVICE}
.PHONY : pull

up : ## (Re)create and (re)start services
	docker compose up \
		--no-build \
		--no-deps \
		--force-recreate \
		--renew-anon-volumes \
		--remove-orphans \
		--wait ${SERVICE}
.PHONY : up

logs : ## Follow logs of services, for example, `make logs` for all services or `make logs SERVICE=reverse_proxy` or `make logs SERVICE="logs metrics"`
	docker compose logs \
		--since=1h \
		--follow ${SERVICE}
.PHONY : logs

shell : ## Enter shell in the service `${SERVICE}`
	docker compose up \
		--no-build \
		--no-deps \
		--no-recreate \
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
	docker volume prune \
		--force \
		--filter "label=com.docker.compose.project=${NAME}"
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

shellcheck = \
	docker run \
		--rm \
		--user $(shell id --user):$(shell id --group) \
		--volume "$(shell pwd):/mnt" \
		--quiet \
		koalaman/shellcheck:v0.11.0 \
		--enable=all \
		--external-sources

dclint = \
	docker run \
		--rm \
		--tty \
		--user $(shell id --user):$(shell id --group) \
		--volume "$(shell pwd):/app" \
		--quiet \
		zavoloklom/dclint:3.1.0 \
		--config /app/.dclintrc

hadolint = \
	docker run \
		--rm \
		--interactive \
		--user $(shell id --user):$(shell id --group) \
		--volume ./.hadolint.yaml:/.config/.hadolint.yaml \
		--quiet \
		hadolint/hadolint:v2.14.0-debian \
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
		mvdan/shfmt:v3.13.0 \
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
