# Concise introduction to GNU Make:
# https://swcarpentry.github.io/make-novice/reference.html

include .env

docker_compose = \
	docker-compose \
		--file docker-compose.yml

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

user : ## Add user `${USER}` (he/she will have access to restricted areas like staging with the correct password), for example, `make USER=jdoe user`
	sudo htpasswd ./nginx/.htpasswd ${USER}
.PHONY : user

setup : ## Setup machine
	NON_WWW_PRODUCTION_HOST=${NON_WWW_PRODUCTION_HOST} \
	EMAIL_ADDRESS=${EMAIL_ADDRESS} \
	SMTP_HOST=${SMTP_HOST} \
	SMTP_PORT=${SMTP_PORT} \
		ansible-playbook local.yml
.PHONY : setup

build : ## Pull and build images
	${docker_compose} pull
	${docker_compose} build \
		--pull
.PHONY : build

up : ## (Re)create and (re)start services
	${docker_compose} up \
		--force-recreate \
		--renew-anon-volumes \
		--remove-orphans \
		--detach \
		reverse_proxy
.PHONY : up

deploy : setup build up ## Deploy services, that is, setup machine, pull and build images, and (re)create and (re)start services
.PHONY : deploy

logs : ## Follow logs
	${docker_compose} logs \
		--follow
.PHONY : logs

down : ## Stop containers and remove containers, networks, volumes, and images created by `deploy`
	${docker_compose} down \
		--remove-orphans
.PHONY : down

crontab : ## List user's and root's contab
	crontab -l
	sudo crontab -u root -l
.PHONY : crontab

monit : ## Follow monit logs
	sudo tail --follow /var/log/monit.log
.PHONY : monit

vacuum-journald : ## Vaccum journald logs keeping seven days worth of logs
	journalctl --rotate
	journalctl --vacuum-time=7d
.PHONY : vacuum-journald

renew-tls : renew-certificates deploy ## Renew Transport Layer Security (TLS) certificates needed for the `S` in `HTTPS`
.PHONY : renew-tls

backup-database : ## Backup production database and prunce backups
	mkdir --parents /app/data/backups
	make \
		--directory=/app/production \
		--file /app/production/Makefile.production \
		DUMP_FILE=/app/data/backups/dump_$(shell date +"\%Y-\%m-\%d_\%H_\%M_\%S").gz \
		backup \
		prune-backups
.PHONY : backup-database

prune-docker : ## Prune docker
	docker system prune \
		--force \
		--filter "until=24h"
.PHONY : prune-docker

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

request-certificates : ## Request certificates
	docker-compose run \
		--rm \
		--entrypoint " \
			certbot certonly \
				--webroot \
				-w /var/www/certbot \
				${STAGING_ARG} \
				${DOMAIN_ARGS} \
				--email ${EMAIL} \
				--key-type ecdsa \
				--elliptic-curve secp256r1 \
				--must-staple \
				--agree-tos \
				--force-renewal \
		" \
		certbot
.PHONY : request-certificate

renew-certificates : ## Renew certificates
	docker-compose run \
		--rm \
		--entrypoint " \
			certbot renew \
		" \
		certbot
.PHONY: renew-certificates

begin-maintenance : ## Begin maintenance
	for environment in staging production ; do \
		make --directory=/app/$${environment} --file=Makefile.production begin-maintenance ; \
	done
.PHONY : begin-maintenance

end-maintenance : ## End maintenance
	if [ -f /var/run/reboot-required ] ; then \
		echo 'Reboot and run `make end-maintenance`' ; \
	else \
		for environment in staging production ; do \
			make --directory=/app/$${environment} --file=Makefile.production end-maintenance ; \
		done ; \
	fi
.PHONY : end-maintenance

upgrade-system : ## Upgrade system (Is used to install the newest versions of all packages currently installed on the system from the sources enumerated in /etc/apt/sources.list. Packages currently installed with new versions available are retrieved and upgraded. Under no circumstances are currently installed packages removed, or packages not already installed retrieved and installed. New versions of currently installed packages that cannot be upgraded without changing the install status of another package will be left at their current version.)
	make begin-maintenance
	sudo apt-get --assume-yes update
	sudo apt-get --assume-yes upgrade
	sudo apt-get --assume-yes auto-remove
	sudo apt-get --assume-yes clean
	sudo apt-get --assume-yes auto-clean
	make end-maintenance
.PHONY : upgrade-system

dist-upgrade-system : ## Upgrade system (In addition to performing the function of `upgrade-system`, also intelligently handles changing dependencies with new versions of packages. It will attempt to upgrade the most important packages at the expense of less important ones if necessary. It may therefore remove some packages.)
	make begin-maintenance
	sudo apt-get --assume-yes update
	sudo apt-get --assume-yes dist-upgrade
	sudo apt-get --assume-yes auto-remove
	sudo apt-get --assume-yes clean
	sudo apt-get --assume-yes auto-clean
	make end-maintenance
.PHONY : dist-upgrade-system

dry-run-unattended-upgrades : ## Dry-run unattended upgrades for testing purposes
	sudo unattended-upgrades \
		--dry-run \
		--debug
.PHONY : dry-run-unattended-upgrades
