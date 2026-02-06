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

begin : ## Begin maintenance
	for environment in staging production ; do \
		$(MAKE) --directory=/app/$${environment} --file=./deploy.mk begin-maintenance ; \
	done
.PHONY : begin

end : ## End maintenance
	if [ -f /var/run/reboot-required ] ; then \
		echo 'Reboot by running `./maintenance.mk reboot` and afterwards run `cd /app/machine && ./maintenance.mk end`' ; \
	else \
		for environment in staging production ; do \
			$(MAKE) --directory=/app/$${environment} --file=./deploy.mk end ; \
		done ; \
	fi
.PHONY : end

prune-docker : ## Prune docker
	docker system prune \
		--force \
		--filter "until=24h"
.PHONY : prune-docker

backup : ## Backup production database
	mkdir --parents /app/data/backups
	$(MAKE) \
		--directory=/app/production \
		--file=./deploy.mk \
		--keep-going \
		BACKUP_DIRECTORY=/app/data/backups/$(shell date +"\%Y-\%m-\%d_\%H_\%M_\%S") \
		begin-maintenance \
		backup \
		end-maintenance
.PHONY : backup-database

# Inspired by https://stackoverflow.com/questions/25785/delete-all-but-the-most-recent-x-files-in-bash/34862475#34862475
prune-backups : ## Keep the most recent 7 backups, delete the rest
	find /app/data/backups \
		-mindepth 1 \
		-maxdepth 1 \
		-type d \
		-execdir rmdir --ignore-fail-on-non-empty '{}' \;
	cd /app/data/backups && \
		ls -t --indicator-style=slash \
		| grep '/$$' \
		| tail --lines=+8 \
		| xargs \
			--delimiter='\n' \
			--no-run-if-empty \
			rm --recursive --dir --
.PHONY : prune-backups

reboot : ## Reboot
	sudo systemctl reboot
.PHONY : reboot

upgrade : ## Upgrade system (Is used to install the newest versions of all packages currently installed on the system from the sources enumerated in /etc/apt/sources.list. Packages currently installed with new versions available are retrieved and upgraded. Under no circumstances are currently installed packages removed, or packages not already installed retrieved and installed. New versions of currently installed packages that cannot be upgraded without changing the install status of another package will be left at their current version.)
	$(MAKE) begin
	sudo apt-get --assume-yes update
	sudo apt-get --assume-yes upgrade
	sudo apt-get --assume-yes auto-remove
	sudo apt-get --assume-yes clean
	sudo apt-get --assume-yes auto-clean
	pipx upgrade-all --include-injected
	$(MAKE) end
.PHONY : upgrade

dist-upgrade : ## Upgrade system (In addition to performing the function of `upgrade`, also intelligently handles changing dependencies with new versions of packages. It will attempt to upgrade the most important packages at the expense of less important ones if necessary. It may therefore remove some packages.)
	$(MAKE) begin
	sudo apt-get --assume-yes update
	sudo apt-get --assume-yes dist-upgrade
	sudo apt-get --assume-yes auto-remove
	sudo apt-get --assume-yes clean
	sudo apt-get --assume-yes auto-clean
	pipx upgrade-all --include-injected
	$(MAKE) end
.PHONY : dist-upgrade

dry-run-unattended-upgrades : ## Dry-run unattended upgrades for testing purposes
	sudo unattended-upgrades \
		--dry-run \
		--debug
.PHONY : dry-run-unattended-upgrades
