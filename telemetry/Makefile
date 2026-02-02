# Concise introduction to GNU Make:
# https://swcarpentry.github.io/make-novice/reference.html

include ./.env

SHELL := /usr/bin/env bash
.SHELLFLAGS := -o errexit -o errtrace -o nounset -o pipefail -c
MAKEFLAGS += --warn-undefined-variables

docker_compose = \
	docker compose \
		--file ./docker-compose.yml \
		--env-file ./.env

# Taken from https://www.client9.com/self-documenting-makefiles/
help : ## Print this help
	@awk -F ':|##' '/^[^\t].+?:.*?##/ {\
		printf "\033[36m%-30s\033[0m %s\n", $$1, $$NF \
	}' $(MAKEFILE_LIST)
.PHONY : help
.DEFAULT_GOAL := help

dotenv : ## Assert that all variables in `./.env.sample` are available in `./.env`
	bash -c " \
		diff \
			<(cut --only-delimited --delimiter='=' --fields=1 ./.env.sample | sort) \
			<(cut --only-delimited --delimiter='=' --fields=1 ./.env        | sort) \
	"
.PHONY : dotenv

pull : ## Pull images
	${docker_compose} pull
.PHONY : pull

up : ## (Re)create and (re)start services
	${docker_compose} up \
		--force-recreate \
		--renew-anon-volumes \
		--remove-orphans \
		--wait
.PHONY : up

logs : ## Follow logs
	${docker_compose} logs \
		--since=24h \
		--follow
.PHONY : logs

shell : ## Enter shell in the `signoz` service
	${docker_compose} up \
		--remove-orphans \
		--wait \
		signoz
	${docker_compose} exec \
		signoz \
		bash
.PHONY : shell

down : ## Stop containers and remove containers, networks, volumes, and images created by `up`
	${docker_compose} down \
		--remove-orphans
.PHONY : down

list : ## List all containers with health status
	${docker_compose} ps \
		--no-trunc \
		--all
.PHONY : list

list-services : ## List all services specified in the docker-compose file (used by Monit)
	${docker_compose} config \
		--services
.PHONY : list-services

remove : ## Remove volumes
	docker volume rm \
		telemetry_clickhouse \
		telemetry_sqlite \
		telemetry_zookeeper
.PHONY : remove

# docker run \
# 	--workdir / \
# 	--volume ./Makefile:/Makefile \
# 	--volume ./checkmake.ini:/checkmake.ini \
# 	quay.io/checkmake/checkmake
lint : ## Lint Docker Compose and Dockerfile
	docker run \
		--rm \
		--tty \
		--volume .:/app \
		zavoloklom/dclint \
		--config /app/.dclintrc \
		.
	docker run \
		--rm \
		--interactive \
		--volume ./.hadolint.yml:/.config/.hadolint.yaml \
		hadolint/hadolint \
		hadolint \
		--config /.config/.hadolint.yaml \
		- \
		< ./Dockerfile
.PHONY : lint

fix : ## Fix Docker linting violations
	docker run \
		--rm \
		--tty \
		--volume .:/app \
		zavoloklom/dclint \
		--fix \
		.
.PHONY : fix
