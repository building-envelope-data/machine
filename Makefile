# Concise introduction to GNU Make:
# https://swcarpentry.github.io/make-novice/reference.html

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
	ansible-playbook local.yml
.PHONY : setup

pull : ## Pull images
	${docker_compose} pull
.PHONY : pull

up : ## (Re)build, (re)create, and (re)start services
	${docker_compose} up \
		--build \
		--force-recreate \
		--renew-anon-volumes \
		--remove-orphans \
		--detach \
		nginx
.PHONY : up

deploy : pull up ## Deploy services
.PHONY : deploy

logs : ## Follow logs
	${docker_compose} logs \
		--follow
.PHONY : logs

down : ## Stop containers and remove containers, networks, volumes, and images created by `deploy`
	${docker_compose} down \
		--remove-orphans
.PHONY : down

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
