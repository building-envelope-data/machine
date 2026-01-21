#!/bin/sh

# https://explainshell.com/explain?cmd=set+-euo
set -euo

export LC_ALL="C.UTF-8"

# Load all variables from .env and export them for Ansible to read
set -o allexport
. "$(dirname "$0")/.env"
set +o allexport

# Run Ansible
exec ansible-playbook "$@"
