#!/bin/sh

running_containers="$(docker ps --no-trunc --all --filter status=running --format '{{.Names}} {{.Status}}')"

environment=machine
services="$(make --silent --directory=/app/machine --file=/app/machine/Makefile list-services)"
echo "Environment: '${environment}'"
echo Services: ${services}
for service in ${services}
do
  if [ "${service}" != "certbot" ] ; then
    if echo "${running_containers}" | grep --quiet --extended-regexp "${environment}_${service}_[0-9] [ a-zA-Z0-9]+ \(healthy\)"
      then echo "Service '${service}' is running and healthy"
    else
      echo "Service '${service}' is not running and/or not healthy: $(docker ps --no-trunc --all --filter name="${environment}_${service}" --format '{{.ID}} {{.Image}} {{.Command}} {{.CreatedAt}} {{.Status}} {{.Ports}} {{.Names}}')" 1>&2
      exit 1
    fi
  fi
done

for environment in staging production
do
  echo "Environment: '${environment}'"
  services="$(make --silent --directory=/app/${environment} --file=/app/${environment}/Makefile.production list-services)"
  echo Services: ${services}
  for service in ${services}
  do
    echo "Service: '${service}'"
    if echo "${running_containers}" | grep --quiet --extended-regexp "[a-zA-Z]+_${environment}_${service}_[0-9] [ a-zA-Z0-9]+ \(healthy\)"
      then echo "Service '${service}' is running and healthy"
    else
      echo "Service '${service}' is not running and/or not healthy: $(docker ps --no-trunc --all --filter name="${environment}_${service}" --format '{{.ID}} {{.Image}} {{.Command}} {{.CreatedAt}} {{.Status}} {{.Ports}} {{.Names}}')" 1>&2
      exit 1
    fi
  done
done
exit 0
