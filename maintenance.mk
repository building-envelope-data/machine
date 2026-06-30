#!/usr/bin/env -S make --file
SELF := $(lastword $(MAKEFILE_LIST))

include ./.env

SHELL := /usr/bin/env bash
.SHELLFLAGS := -o errexit -o errtrace -o nounset -o pipefail -c
MAKEFLAGS += --warn-undefined-variables

# Taken from https://www.client9.com/self-documenting-makefiles/
help : ## Print this help
	@awk -F ':.*?## ' '/^[^\t].+?:.*?##/ {\
		printf "\033[36m%-30s\033[0m %s\n", $$1, $$NF \
	}' $(MAKEFILE_LIST)
.PHONY : help
.DEFAULT_GOAL := help

begin : ## Begin maintenance
	for environment in staging production ; do \
		$(MAKE) --directory=/app/$${environment} --file=/app/$${environment}/deploy.mk begin-maintenance ; \
	done
.PHONY : begin

end : ## End maintenance
	if [ -f /var/run/reboot-required ] ; then \
		echo 'Reboot by running `./maintenance.mk reboot` and afterwards run `cd /app/machine && ./maintenance.mk end`' ; \
	else \
		for environment in staging production ; do \
			$(MAKE) --directory=/app/$${environment} --file=/app/$${environment}/deploy.mk end-maintenance ; \
		done ; \
	fi
.PHONY : end

renew-tls : ## Renew Transport Layer Security (TLS) certificates needed for the `S` in `HTTPS` (used by Cron)
	$(MAKE) --file=./certificates.mk renew
	$(MAKE) --file=./docker.mk up SERVICE=reverse_proxy
.PHONY : renew-tls

prune-docker : ## Prune docker
	docker system prune \
		--force \
		--filter "until=24h"
	docker image prune \
		--force \
		--all \
		--filter "until=$(shell echo $$((30*24)))h" \
		--filter "label=com.docker.compose.service=backend"
	docker image prune \
		--force \
		--all \
		--filter "until=$(shell echo $$((30*24)))h" \
		--filter "label=com.docker.compose.service=frontend"
.PHONY : prune-docker

backups_dir=/app/data/backups
content_addressable_storage=/app/data/backups/.content-addressable-storage

backup : ## Backup production database
	mkdir --parents \
		${backups_dir} \
		${content_addressable_storage}
	$(MAKE) \
		--directory=/app/production \
		--file=/app/production/database.mk \
		backup \
		DIR="${backups_dir}/$(shell date +"%Y-%m-%d_%H_%M_%S")" \
		CONTENT_ADDRESSABLE_STORAGE=${content_addressable_storage}
.PHONY : backup

# Inspired by https://stackoverflow.com/questions/25785/delete-all-but-the-most-recent-x-files-in-bash/34862475#34862475
prune-backups : ## Keep the most recent 30 backups, delete the rest
	find ${backups_dir} \
		-mindepth 1 \
		-maxdepth 1 \
		-type d \
		-not -path '.*' \
		-execdir rmdir --ignore-fail-on-non-empty '{}' \;
	cd ${backups_dir} && \
		ls -t --indicator-style=slash \
		| grep '/$$' \
		| tail --lines=+31 \
		| xargs \
			--delimiter='\n' \
			--no-run-if-empty \
			rm --recursive --dir --
	find ${content_addressable_storage} -mindepth 1 -maxdepth 1 -type f -printf "%f\n" | while read -r hash_value; do \
		if [[ -z "$$(find ${backups_dir} -type l -lname "*/$${hash_value}" -print -quit)" ]]; then \
			echo "No symbolic link within ${backups_dir} links to ${content_addressable_storage}/$${hash_value}. Removing it..." ; \
			rm "${content_addressable_storage}/$${hash_value}" ; \
		fi \
	done
.PHONY : prune-backups

restart : ## Restart service `${SERVICE}` in environment `${ENV}`, for example, `./maintenance.mk restart SERVICE=backend ENV=staging`
	$(MAKE) \
		--directory=/app/${ENV} \
		--file=/app/${ENV}/deploy.mk \
		--keep-going \
		begin-maintenance \
		restart \
		end-maintenance \
		SERVICE=${SERVICE}
.PHONY : restart

reboot : ## Reboot
	sudo systemctl reboot
.PHONY : reboot

upgrade : ## Upgrade system (Is used to install the newest versions of all packages currently installed on the system from the sources enumerated in /etc/apt/sources.list. Packages currently installed with new versions available are retrieved and upgraded. Under no circumstances are currently installed packages removed, or packages not already installed retrieved and installed. New versions of currently installed packages that cannot be upgraded without changing the install status of another package will be left at their current version.)
	$(MAKE) --file="${SELF}" begin
	sudo apt-get --assume-yes update
	sudo apt-get --assume-yes upgrade
	sudo apt-get --assume-yes auto-remove
	sudo apt-get --assume-yes clean
	sudo apt-get --assume-yes auto-clean
	pipx upgrade-all --include-injected
	$(MAKE) --file="${SELF}" end
.PHONY : upgrade

dist-upgrade : ## Upgrade system (In addition to performing the function of `upgrade`, also intelligently handles changing dependencies with new versions of packages. It will attempt to upgrade the most important packages at the expense of less important ones if necessary. It may therefore remove some packages.)
	$(MAKE) --file="${SELF}" begin
	sudo apt-get --assume-yes update
	sudo apt-get --assume-yes dist-upgrade
	sudo apt-get --assume-yes auto-remove
	sudo apt-get --assume-yes clean
	sudo apt-get --assume-yes auto-clean
	pipx upgrade-all --include-injected
	$(MAKE) --file="${SELF}" end
.PHONY : dist-upgrade

dry-run-unattended-upgrades : ## Dry-run unattended upgrades for testing purposes
	sudo unattended-upgrades \
		--dry-run \
		--debug
.PHONY : dry-run-unattended-upgrades
