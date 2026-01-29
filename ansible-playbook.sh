#!/bin/bash
# [Bash Strict Mode](https://github.com/olivergondza/bash-strict-mode)
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

export LC_ALL="C.UTF-8"

# Load all variables from .env and export them for Ansible to read
set -o allexport
. "$(dirname "$0")/.env"
set +o allexport

# Run Ansible
exec ansible-playbook "$@"
