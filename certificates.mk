#!/usr/bin/env -S make --file
SELF := $(lastword $(MAKEFILE_LIST))

include ./.env

SHELL := /usr/bin/env bash
.SHELLFLAGS := -o errexit -o errtrace -o nounset -o pipefail -c
MAKEFLAGS += --warn-undefined-variables

COMPOSE_BAKE=true

# Taken from https://www.client9.com/self-documenting-makefiles/
help : ## Print this help
	@awk -F ':|##' '/^[^\t].+?:.*?##/ {\
		printf "\033[36m%-30s\033[0m %s\n", $$1, $$NF \
	}' $(MAKEFILE_LIST)
.PHONY : help
.DEFAULT_GOAL := help

dummy : ## Create dummy certificates for `${DOMAIN}`
	mkdir --parents "./certbot/conf/live/${DOMAIN}"
	docker compose run \
		--rm \
		--pull "always" \
		--user $(shell id --user):$(shell id --group) \
		--entrypoint " \
			openssl req \
				-x509 \
				-nodes \
				-newkey rsa:4096 \
				-days 1 \
				-keyout '/etc/letsencrypt/live/${DOMAIN}/privkey.pem' \
				-out '/etc/letsencrypt/live/${DOMAIN}/fullchain.pem' \
				-subj '/CN=localhost' \
		" \
		certbot
.PHONY : dummy

delete : ## Delete certificates for `${DOMAIN}`
	docker compose run \
		--rm \
		--pull "always" \
		--user $(shell id --user):$(shell id --group) \
		--entrypoint " \
			rm -r -f \
				'/etc/letsencrypt/live/${DOMAIN}' \
				'/etc/letsencrypt/archive/${DOMAIN}' \
				'/etc/letsencrypt/renewal/${DOMAIN}.conf' \
		" \
		certbot
.PHONY : delete-dummy

# For certbot options see
# https://eff-certbot.readthedocs.io/en/latest/using.html#certbot-commands
request : ## Request certificates
	docker compose run \
		--rm \
		--pull "always" \
		--user $(shell id --user):$(shell id --group) \
		--entrypoint " \
			certbot certonly \
				-v \
				--non-interactive \
				--webroot \
				--webroot-path /var/www/certbot \
				${STAGING_ARG} \
				${DOMAIN_ARGS} \
				--email '${EMAIL}' \
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
.PHONY : request

renew : ## Renew certificates
	docker compose run \
		--rm \
		--pull "always" \
		--entrypoint "certbot renew" \
		certbot
.PHONY: renew
