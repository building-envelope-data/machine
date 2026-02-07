#!/usr/bin/env bash
# [Bash Strict Mode](https://github.com/olivergondza/bash-strict-mode)
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
# shellcheck disable=SC2154 # warning: s is referenced but not assigned.
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

# Inspired by https://github.com/wmnnd/nginx-certbot/blob/master/init-letsencrypt.sh

# For the option `allexport` see https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
set -o allexport
. "$(dirname "$0")/.env"
set +o allexport

if ! docker compose version; then
  echo 'Error: docker compose is not installed.' >&2
  exit 1
fi

domains=("${HOST}" "${PRODUCTION_SUBDOMAIN}.${HOST}" "${STAGING_SUBDOMAIN}.${HOST}" "${TELEMETRY_SUBDOMAIN}.${HOST}" "${EXTRA_HOST}")
email="${EMAIL_ADDRESS}"
staging=0 # Set to 1 if you're testing your setup to avoid hitting request limits

if [[ -d "./certbot" ]]; then
  read -r -p "Existing data found. Continue and replace existing certificate(s)? (y/N) " decision
  if [[ ${decision} != "Y" ]] && [[ ${decision} != "y" ]]; then
    exit
  fi
fi

echo "### Creating certbot config, working, logs, and certificates directories ./certbot/* ..."
mkdir --parents \
  "./certbot/conf/accounts" \
  "./certbot/letsencrypt" \
  "./certbot/logs" \
  "./certbot/www"
chmod --recursive 755 "./certbot"
chmod --recursive 700 \
  "./certbot/conf/accounts" \
  "./certbot/logs"

if [[ ! -e "./certbot/conf/options-ssl-nginx.conf" ]] || [[ ! -e "./certbot/conf/ssl-dhparams.pem" ]]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir --parents "./certbot/conf"
  curl --silent https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "./certbot/conf/options-ssl-nginx.conf"
  curl --silent https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "./certbot/conf/ssl-dhparams.pem"
  echo
fi

# Needed to (re)deploy nginx.
echo "### Creating dummy certificate for ${domains[0]} ..."
./certificates.mk DOMAIN="${domains[0]}" dummy
echo

# Needed to serve certbots ACME challenge under /.well-known/acme-challenge/
echo "### (Re)deploying nginx ..."
./docker.mk pull up SERVICE=reverse_proxy
echo

if [[ "${ENVIRONMENT}" != "development" ]]; then
  echo "### Deleting dummy certificate for ${domains[0]} ..."
  ./certificates.mk DOMAIN="${domains[0]}" delete
  echo
fi

echo "### Requesting Let's Encrypt certificate for ${domains[0]} ..."
# Join ${domains} to -d args
domain_args=""
for domain in "${domains[@]}"; do
  if [[ -n "${domain}" ]]; then
    domain_args="${domain_args} -d \"${domain}\""
  fi
done

# Enable staging mode if needed
staging_arg=""
if [[ ${staging} != "0" ]]; then staging_arg="--staging"; fi

./certificates.mk \
  STAGING_ARG="${staging_arg}" \
  DOMAIN_ARGS="${domain_args}" \
  EMAIL="${email}" \
  request
echo
