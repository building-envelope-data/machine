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

# See https://docs.docker.com/config/daemon/#view-stack-traces
daemon : ## Follow Docker daemon logs
	sudo journalctl \
		--follow \
		--unit docker.service
.PHONY : daemon

cron : ## Follow Cron logs
	sudo journalctl \
		--follow \
		--unit cron.service
.PHONY : cron

monit : ## Follow Monit logs
	sudo journalctl \
		--follow \
		--unit monit.service
.PHONY : monit

msmtp : ## Follow msmtp logs
	sudo journalctl \
		--follow \
		--unit msmtp.service
.PHONY : msmtp

certbot : ## Follow Certbot logs
	tail \
		./certbot/logs/*.log
.PHONY : certbot

rotate : ## Rotate logs
	sudo journalctl --rotate
	sudo logrotate /etc/logrotate.conf
.PHONY : rotate

vacuum : ## Vaccum journald logs keeping seven days worth of logs
	journalctl --vacuum-time=7d
.PHONY : vacuum

clean-up : ## Clean-up backed up logs
	sudo find /var/log -type f -name "*.gz" -delete
	sudo find /var/log -type f -name "*.[0-9]*.log" -delete
	find ./certbot/logs -type f -name "*.log.[0-9]*" -delete
.PHONY : clean-up
