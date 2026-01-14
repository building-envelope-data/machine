#!/bin/bash

# Inspired by https://github.com/wmnnd/nginx-certbot/blob/master/init-letsencrypt.sh

# For the option `allexport` see https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
set -o allexport
source .env
set +o allexport

if ! docker compose version; then
  echo 'Error: docker compose is not installed.' >&2
  exit 1
fi

domains=("${NON_WWW_PRODUCTION_HOST}" "${PRODUCTION_HOST}" "${STAGING_HOST}" "${FRAUNHOFER_HOST}")
email="${EMAIL_ADDRESS}"
staging=0 # Set to 1 if you're testing your setup to avoid hitting request limits

if [ -d "./certbot" ]; then
  read -p "Existing data found. Continue and replace existing certificate(s)? (y/N) " decision
  if [ "${decision}" != "Y" ] && [ "${decision}" != "y" ]; then
    exit
  fi
fi

if [ ! -e "./certbot/conf/options-ssl-nginx.conf" ] || [ ! -e "./certbot/conf/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "./certbot/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "./certbot/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "./certbot/conf/ssl-dhparams.pem"
  echo
fi

echo "### Creating dummy certificate for ${domains} ..."
mkdir -p "./certbot/conf/live/${domains}"
make OUT_PATH="/etc/letsencrypt/live/${domains}" dummy-certificates
echo

echo "### (Re)deploying nginx ..."
make deploy
echo

echo "### Deleting dummy certificate for ${domains} ..."
make DOMAINS="${domains}" delete-dummy-certificates
echo

echo "### Requesting Let's Encrypt certificate for ${domains} ..."
#Join ${domains} to -d args
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="${domain_args} -d ${domain}"
done

# Enable staging mode if needed
if [ ${staging} != "0" ]; then staging_arg="--staging"; fi

make \
  STAGING_ARG="${staging_arg}" \
  DOMAIN_ARGS="${domain_args}" \
  EMAIL="${email}" \
  request-certificates
echo

echo "### (Re)deploying nginx ..."
make deploy
