# Concise introduction to GNU Make:
# https://swcarpentry.github.io/make-novice/reference.html

include ./.env
include ./telemetry/.env

SHELL := /bin/bash
.SHELLFLAGS := -o errexit -o errtrace -o nounset -o pipefail -c
MAKEFLAGS += --warn-undefined-variables

docker_compose = \
	TELEMETRY_HTTP_PORT=${TELEMETRY_HTTP_PORT} \
		docker compose \
			--file ./docker-compose.yml \
			--env-file ./.env

make_telemetry = \
	$(MAKE) \
		--directory=./telemetry \

# Taken from https://www.client9.com/self-documenting-makefiles/
help : ## Print this help
	@awk -F ':|##' '/^[^\t].+?:.*?##/ {\
		printf "\033[36m%-30s\033[0m %s\n", $$1, $$NF \
	}' $(MAKEFILE_LIST)
.PHONY : help
.DEFAULT_GOAL := help

scan : ## Scan for additional hard disks without restarting the virtual machine
	sudo rescan-scsi-bus.sh
.PHONY : scan

network-interfaces : ## List network interfaces
	ip link
.PHONY : network-interfaces

password : ## Generate a password
	openssl rand -base64 32
.PHONY : password

monit : ## Print Monit status and summary
	sudo monit status
	sudo monit summary
.PHONY : monit

crontab : ## List user's and root's contab
	crontab -l
	sudo crontab -u root -l
.PHONY : crontab

# --------------------------------------------------------------------------
# Deploy and Interface with Docker

dotenv : ## Assert that all variables in `./.env.sample` are available in `./.env`
	bash -c " \
		diff \
			<(cut --delimiter='=' --fields=1 ./.env.sample | sort) \
			<(cut --delimiter='=' --fields=1 ./.env        | sort) \
	"
	bash -c " \
		diff \
			<(cut --delimiter='=' --fields=1 ./.env.sample | sort) \
			<(cut --delimiter='=' --fields=1 ./.env.buildingenvelopedata.sample | sort) \
	"
	bash -c " \
		diff \
			<(cut --delimiter='=' --fields=1 ./.env.sample | sort) \
			<(cut --delimiter='=' --fields=1 ./.env.solarbuildingenvelopes.sample | sort) \
	"
	${make_telemetry} dotenv
.PHONY : dotenv

htpasswd : ## Create file ./nginx/.htpasswd if it does not exist
	if [ -f ./nginx/.htpasswd ] ; then \
		sudo touch ./nginx/.htpasswd && \
		sudo chmod 600 ./nginx/.htpasswd ; \
	fi
.PHONY : htpasswd

user : htpasswd ## Add user `${USER}` (he/she will have access to restricted areas like staging and the Monit web interface with the correct password), for example, `make USER=jdoe user`
	sudo htpasswd ./nginx/.htpasswd ${USER}
.PHONY : user

setup : htpasswd ## Setup machine
	./ansible-playbook.sh ./local.yml
.PHONY : setup

pull : ## Pull images
	${docker_compose} pull
	${make_telemetry} pull
.PHONY : pull

up : ## (Re)create and (re)start services
	${docker_compose} up \
		--force-recreate \
		--renew-anon-volumes \
		--remove-orphans \
		--detach \
		reverse_proxy
	${make_telemetry} up
.PHONY : up

deploy : dotenv setup pull up ## Deploy services, that is, assert ./.env file, setup machine, pull images, and (re)create and (re)start services
.PHONY : deploy

logs : ## Follow logs
	${docker_compose} logs \
		--since=24h \
		--follow & \
	${make_telemetry} logs & \
	wait
.PHONY : logs

shell : ## Enter shell in the `reverse_proxy` service
	${docker_compose} up \
		--remove-orphans \
		--detach \
		reverse_proxy
	${docker_compose} exec \
		reverse_proxy \
		bash
.PHONY : shell

machine : ## Enter shell in the `machine` service for debugging and testing, for example by running `make setup` or `make --file=Makefile.ansible lint`
	COMPOSE_BAKE=true \
		COMPOSE_DOCKER_CLI_BUILD=1 \
			DOCKER_BUILDKIT=1 \
				${docker_compose} build \
					--build-arg GROUP_ID=$(shell id --group) \
					--build-arg USER_ID=$(shell id --user) \
					machine
	${docker_compose} run \
		--rm \
		--remove-orphans \
		--user $(shell id --user):$(shell id --group) \
		machine \
		bash
.PHONY : shell

down : ## Stop containers and remove containers, networks, volumes, and images created by `deploy`
	${docker_compose} down \
		--remove-orphans
	${make_telemetry} down
.PHONY : down

list : ## List all containers with health status
	${docker_compose} ps \
		--no-trunc \
		--all
	${make_telemetry} ps
.PHONY : list

list-services : ## List all services specified in the docker-compose file (used by Monit)
	${docker_compose} config \
		--services
	${make_telemetry} config
.PHONY : list-services

# docker run \
# 	--workdir / \
# 	--volume ./checkmake.ini:/checkmake.ini \
# 	--volume ./Makefile:/Makefile \
# 	--volume ./Makefile.development:/Makefile.development \
# 	quay.io/checkmake/checkmake \
# 	/Makefile \
# 	/Makefile.development
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
	${make_telemetry} lint
.PHONY : lint

fix : ## Fix Docker Compoe linting violations
	docker run \
		--rm \
		--tty \
		--volume .:/app \
		zavoloklom/dclint \
		--fix \
		.
	${make_telemetry} fix
.PHONY : fix

# See https://docs.docker.com/config/containers/runmetrics/
docker-stats : ## Show Docker run-time metrics
	docker stats
.PHONY : docker-stats

prune-docker : ## Prune docker
	docker system prune \
		--force \
		--filter "until=24h"
.PHONY : prune-docker

reload-daemon : ## Reload Docker daemon
	sudo systemctl \
		reload docker
.PHONY : reload-daemon

# --------------------------------------------------------------------------
# Logs

# See https://docs.docker.com/config/daemon/#view-stack-traces
daemon-logs : ## Follow Docker daemon logs
	sudo journalctl \
		--follow \
		--unit docker.service
.PHONY : daemon-logs

cron-logs : ## Follow Cron logs
	sudo journalctl \
		--follow \
		--unit cron.service
.PHONY : cron-logs

monit-logs : ## Follow Monit logs
	sudo tail \
		--follow \
		/var/log/monit.log
.PHONY : monit-logs

smtp-logs : ## Follow msmtp logs
	sudo tail \
		--follow \
		/var/log/msmtp \
		~/.msmtp.log
.PHONY : smtp-logs

certbot-logs : ## Follow Certbot logs
	tail \
		./certbot/logs/*.log
.PHONY : certbot-logs

vacuum-journald : ## Vaccum journald logs keeping seven days worth of logs
	journalctl --rotate
	journalctl --vacuum-time=7d
.PHONY : vacuum-journald

clear-logs : ## Delete archived and backuped logs
	find /var/log -type f -name "*.gz" -delete
	find /var/log -type f -name "*.[0-9].log" -delete
.PHONY : clear-logs

# --------------------------------------------------------------------------
# TLS Certificates

renew-tls : renew-certificates deploy ## Renew Transport Layer Security (TLS) certificates needed for the `S` in `HTTPS`
.PHONY : renew-tls

dummy-certificates : ## Create dummy certificates for `${OUT_PATH}`
	${docker_compose} run \
		--rm \
		--entrypoint " \
			openssl req \
				-x509 \
				-nodes \
				-newkey rsa:4096 \
				-days 1 \
				-keyout '${OUT_PATH}/privkey.pem' \
				-out '${OUT_PATH}/fullchain.pem' \
				-subj '/CN=localhost' \
		" \
		certbot
.PHONY : dummy-certificates

delete-dummy-certificates : ## Delete dummy certificates for `${DOMAINS}`
	${docker_compose} run \
		--rm \
		--entrypoint " \
			rm -R -f \
				/etc/letsencrypt/live/${DOMAINS} \
				/etc/letsencrypt/archive/${DOMAINS} \
				/etc/letsencrypt/renewal/${DOMAINS}.conf \
		" \
		certbot
.PHONY : delete-dummy-certificates

# For certbot options see
# https://eff-certbot.readthedocs.io/en/latest/using.html#certbot-commands
request-certificates : ## Request certificates
	${docker_compose} run \
		--rm \
		--user $(shell id --user):$(shell id --group) \
		--entrypoint " \
			certbot certonly \
				-v \
				--non-interactive \
				--webroot \
				--webroot-path /var/www/certbot \
				${STAGING_ARG} \
				${DOMAIN_ARGS} \
				--email ${EMAIL} \
				--keep-until-expiring \
				--expand \
				--renew-with-new-domains \
				--no-reuse-key \
				--agree-tos \
				--key-type ecdsa \
				--elliptic-curve secp256r1 \
				--hsts \
				--uir \
				--strict-permissions \
		" \
		certbot
.PHONY : request-certificates

renew-certificates : ## Renew certificates
	${docker_compose} run \
		--rm \
		--entrypoint " \
			certbot renew \
		" \
		certbot
.PHONY: renew-certificates

# --------------------------------------------------------------------------
# Maintenance

begin-maintenance : ## Begin maintenance
	for environment in staging production ; do \
		$(MAKE) --directory=/app/$${environment} --file=Makefile.production begin-maintenance ; \
	done
.PHONY : begin-maintenance

end-maintenance : ## End maintenance
	if [ -f /var/run/reboot-required ] ; then \
		echo 'Reboot by running `make reboot` and afterwards run `cd /app/machine && make end-maintenance`' ; \
	else \
		for environment in staging production ; do \
			$(MAKE) --directory=/app/$${environment} --file=Makefile.production end-maintenance ; \
		done ; \
	fi
.PHONY : end-maintenance

backup-database : ## Backup production database and prune backups
	mkdir --parents /app/data/backups
	$(MAKE) \
		--directory=/app/production \
		--file /app/production/Makefile.production \
		--keep-going \
		BACKUP_DIRECTORY=/app/data/backups/$(shell date +"\%Y-\%m-\%d_\%H_\%M_\%S") \
		begin-maintenance \
		backup \
		end-maintenance \
		prune-backups
.PHONY : backup-database

reboot : ## Reboot
	sudo systemctl reboot
.PHONY : reboot

upgrade : ## Upgrade system (Is used to install the newest versions of all packages currently installed on the system from the sources enumerated in /etc/apt/sources.list. Packages currently installed with new versions available are retrieved and upgraded. Under no circumstances are currently installed packages removed, or packages not already installed retrieved and installed. New versions of currently installed packages that cannot be upgraded without changing the install status of another package will be left at their current version.)
	$(MAKE) begin-maintenance
	sudo apt-get --assume-yes update
	sudo apt-get --assume-yes upgrade
	sudo apt-get --assume-yes auto-remove
	sudo apt-get --assume-yes clean
	sudo apt-get --assume-yes auto-clean
	pipx upgrade-all --include-injected
	$(MAKE) end-maintenance
.PHONY : upgrade

dist-upgrade : ## Upgrade system (In addition to performing the function of `upgrade`, also intelligently handles changing dependencies with new versions of packages. It will attempt to upgrade the most important packages at the expense of less important ones if necessary. It may therefore remove some packages.)
	$(MAKE) begin-maintenance
	sudo apt-get --assume-yes update
	sudo apt-get --assume-yes dist-upgrade
	sudo apt-get --assume-yes auto-remove
	sudo apt-get --assume-yes clean
	sudo apt-get --assume-yes auto-clean
	pipx upgrade-all --include-injected
	$(MAKE) end-maintenance
.PHONY : dist-upgrade

dry-run-unattended-upgrades : ## Dry-run unattended upgrades for testing purposes
	sudo unattended-upgrades \
		--dry-run \
		--debug
.PHONY : dry-run-unattended-upgrades
