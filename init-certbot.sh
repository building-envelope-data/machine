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
  if [[ "${decision}" != "Y" ]] && [[ "${decision}" != "y" ]]; then
    exit
  fi
fi

echo "### Creating certbot config, working, logs, and certificates directories ./certbot/* ..."
mkdir --parents "./certbot/conf/accounts"
mkdir --parents "./certbot/letsencrypt"
mkdir --parents "./certbot/logs"
mkdir --parents "./certbot/www"
chmod --recursive 755 "./certbot/conf"
chmod --recursive 700 "./certbot/conf/accounts"
chmod --recursive 755 "./certbot/letsencrypt"
chmod --recursive 700 "./certbot/logs"
chmod --recursive 755 "./certbot/www"

if [[ ! -e "./certbot/conf/options-ssl-nginx.conf" ]] || [[ ! -e "./certbot/conf/ssl-dhparams.pem" ]]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir --parents "./certbot/conf"
  curl --silent https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "./certbot/conf/options-ssl-nginx.conf"
  curl --silent https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "./certbot/conf/ssl-dhparams.pem"
  echo
fi

echo "### Creating dummy certificate for ${domains[0]} ..."
mkdir --parents "./certbot/conf/live/${domains[0]}"
make OUT_PATH="/etc/letsencrypt/live/${domains[0]}" dummy-certificates
echo

echo "### (Re)deploying nginx ..."
make deploy
echo

echo "### Deleting dummy certificate for ${domains[0]} ..."
make DOMAINS="${domains[0]}" delete-dummy-certificates
echo

echo "### Requesting Let's Encrypt certificate for ${domains[0]} ..."
#Join ${domains} to -d args
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="${domain_args} -d ${domain}"
done

# Enable staging mode if needed
staging_arg=""
if [[ ${staging} != "0" ]]; then staging_arg="--staging"; fi

make \
  STAGING_ARG="${staging_arg}" \
  DOMAIN_ARGS="${domain_args}" \
  EMAIL="${email}" \
  request-certificates
echo

echo "### (Re)deploying nginx ..."
make deploy
