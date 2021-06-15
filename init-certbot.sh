#!/bin/bash

# Inspired by https://github.com/wmnnd/nginx-certbot/blob/master/init-letsencrypt.sh

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

domains=(buildingenvelopedata.org www.buildingenvelopedata.org staging.buildingenvelopedata.org)
email="simon.wacker@ise.fraunhofer.de"
staging=1 # Set to 1 if you're testing your setup to avoid hitting request limits

if [ -d "./certbot" ]; then
  read -p "Existing data found. Continue and replace existing certificate(s)? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
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

echo "### Creating dummy certificate for $domains ..."
mkdir -p "./certbot/conf/live/$domains"
make OUT_PATH="/etc/letsencrypt/live/$domains" dummy-certificates
echo

echo "### Starting nginx ..."
docker-compose up \
  --force-recreate \
  --detach \
  reverse_proxy
echo

echo "### Deleting dummy certificate for $domains ..."
make DOMAINS="${domains}" delete-dummy-certificates
echo

echo "### Requesting Let's Encrypt certificate for $domains ..."
#Join $domains to -d args
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

# Select appropriate email arg
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# Enable staging mode if needed
if [ $staging != "0" ]; then staging_arg="--staging"; fi

docker-compose run \
  --rm \
  --entrypoint "\
    certbot certonly \
      --webroot \
      -w /var/www/certbot \
      $staging_arg \
      $email_arg \
      $domain_args \
      --key-type ecdsa \
      --elliptic-curve secp256r1 \
      --must-staple \
      --agree-tos \
      --force-renewal \
  " \
  certbot
echo

echo "### Reloading nginx ..."
docker-compose exec \
  reverse_proxy \
  nginx -s reload
