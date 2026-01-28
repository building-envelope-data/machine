# Concise introduction to GNU Make:
# https://swcarpentry.github.io/make-novice/reference.html

include ./.env

docker_compose = \
	docker compose \
		--file ./docker-compose.yml

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
			<(cut --delimiter='=' --fields=1 ./.env.sample | sort) \
			<(cut --delimiter='=' --fields=1 ./.env        | sort) \
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
		--detach
.PHONY : up

logs : ## Follow logs
	${docker_compose} logs \
		--since=24h \
		--follow
.PHONY : logs

shell : ## Enter shell in the `signoz` service
	${docker_compose} up \
		--remove-orphans \
		--detach \
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
