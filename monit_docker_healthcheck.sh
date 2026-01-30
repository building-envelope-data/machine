#!/bin/bash
# [Bash Strict Mode](https://github.com/olivergondza/bash-strict-mode)
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

echo "Docker Healthcheck"

running_containers="$(docker ps --no-trunc --all --filter status=running --format '{{.Names}} {{.Status}}')"
echo "  Running Containers: '${running_containers}'" | tr '\n' '\t'

environment=machine
services="$(make --silent --directory=/app/machine --file=/app/machine/Makefile list-services | tr '\n' ' ')"
echo "  Environment: '${environment}'"
echo "    Services: '${services}'"
for service in ${services}
do
  if [ "${service}" != "certbot" -a "${service}" != "machine" ] ; then
    if echo "${running_containers}" | grep --quiet --extended-regexp "^${environment}-${service}-[0-9] [ a-zA-Z0-9]+ \(healthy\)$" ; then
      echo "    Service '${service}' is running and healthy"
    else
      echo "    Service '${service}' is not running and/or not healthy: $(docker ps --no-trunc --all --filter name="${environment}-${service}" --format '{{.ID}} {{.Image}} {{.Command}} {{.CreatedAt}} {{.Status}} {{.Ports}} {{.Names}}')" 1>&2
      exit 1
    fi
  fi
done

for environment in staging production
do
  echo "  Environment: '${environment}'"
  services="$(make --silent --directory=/app/${environment} --file=/app/${environment}/Makefile.production list-services | tr '\n' ' ')"
  echo "    Services: '${services}'"
  for service in ${services}
  do
    if echo "${running_containers}" | grep --quiet --extended-regexp "^[a-zA-Z]+_${environment}-${service}-[0-9] [ a-zA-Z0-9]+ \(healthy\)$" ; then
      echo "    Service '${service}' is running and healthy"
    else
      echo "    Service '${service}' is not running and/or not healthy: $(docker ps --no-trunc --all --filter name="${environment}-${service}" --format '{{.ID}} {{.Image}} {{.Command}} {{.CreatedAt}} {{.Status}} {{.Ports}} {{.Names}}')" 1>&2
      exit 1
    fi
  done
done
exit 0
