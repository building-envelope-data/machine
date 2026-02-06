#!/usr/bin/env -S make --file

include ./.env

SHELL := /usr/bin/env bash
.SHELLFLAGS := -o errexit -o errtrace -o nounset -o pipefail -c
MAKEFLAGS += --warn-undefined-variables

COMPOSE_BAKE=true

docker_compose = \
	docker compose \
		--env-file ./.env

# Taken from https://www.client9.com/self-documenting-makefiles/
help : ## Print this help
	@awk -F ':|##' '/^[^\t].+?:.*?##/ {\
		printf "\033[36m%-30s\033[0m %s\n", $$1, $$NF \
	}' $(MAKEFILE_LIST)
.PHONY : help
.DEFAULT_GOAL := help

# TODO
tls : ## Renew Transport Layer Security (TLS) certificates needed for the `S` in `HTTPS`
	$(MAKE) renew
	$(MAKE) --file=./Makfile deploy
.PHONY : tls

dummy : ## Create dummy certificates for `${DOMAIN}`
	mkdir --parents "./certbot/conf/live/${DOMAIN}"
	${docker_compose} run \
		--rm \
		--entrypoint ' \
			openssl req \
				-x509 \
				-nodes \
				-newkey rsa:4096 \
				-days 1 \
				-keyout "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" \
				-out "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" \
				-subj '/CN=localhost' \
		' \
		certbot
.PHONY : dummy

delete : ## Delete certificates for `${DOMAIN}`
	${docker_compose} run \
		--rm \
		--entrypoint ' \
			rm --recursive --force \
				"/etc/letsencrypt/live/${DOMAIN}" \
				"/etc/letsencrypt/archive/${DOMAIN}" \
				"/etc/letsencrypt/renewal/${DOMAIN}.conf" \
		' \
		certbot
.PHONY : delete-dummy

# For certbot options see
# https://eff-certbot.readthedocs.io/en/latest/using.html#certbot-commands
request : ## Request certificates
	${docker_compose} run \
		--rm \
		--user $(shell id --user):$(shell id --group) \
		--entrypoint ' \
			certbot certonly \
				-v \
				--non-interactive \
				--webroot \
				--webroot-path /var/www/certbot \
				"${STAGING_ARG}" \
				"${DOMAIN_ARGS}" \
				--email "${EMAIL}" \
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
		' \
		certbot
.PHONY : request

renew : ## Renew certificates
	${docker_compose} run \
		--rm \
		--entrypoint "certbot renew" \
		certbot
.PHONY: renew
