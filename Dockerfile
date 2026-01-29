# syntax=docker/dockerfile:1.21
# check=error=true
# Available versions are listed on https://hub.docker.com/r/docker/dockerfile

FROM debian:bookworm
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

ARG GROUP_ID
ARG USER_ID

RUN \
  if [ -z "$GROUP_ID" ]; then echo "required 'GROUP_ID'"; exit 1; fi && \
  if [ -z "$USER_ID" ]; then echo "required 'USER_ID'"; exit 1; fi

# Create non-root user to run commands in (see https://medium.com/@mccode/processes-in-containers-should-not-run-as-root-2feae3f0df3b)
# id --user --name "${USER_ID}" 2>/dev/null
RUN \
  apt-get update && \
  apt-get install \
    --assume-yes \
    --no-install-recommends \
    adduser \
    sudo && \
  existing_user_name="$( (getent passwd ${USER_ID} 2>/dev/null || true) | cut --delimiter=: --fields=1)" && \
  if test -n "${existing_user_name}"; then \
    deluser "${existing_user_name}"; \
  fi && \
  existing_group_name="$( (getent group ${GROUP_ID} 2>/dev/null || true) | cut --delimiter=: --fields=1)" && \
  if test -n "${existing_group_name}"; then \
    delgroup "${existing_group_name}"; \
  fi && \
  addgroup \
    --system \
    --gid "${GROUP_ID}" \
    us && \
  adduser \
    --system \
    --home /home/me \
    --uid "${USER_ID}" \
    --ingroup us \
    me && \
  usermod \
    --append \
    --groups sudo \
    me && \
  echo "me ALL=(ALL) NOPASSWD:ALL" \
    >> /etc/sudoers.d/me && \
  chmod 0440 /etc/sudoers.d/me && \
  rm \
    --recursive \
    --force \
    /var/lib/apt/lists/*

#############
# As `root` #
#############

# The Ubuntu codename for the Debian distribution can be found on
# https://docs.ansible.com/projects/ansible/latest/installation_guide/installation_distros.html#installing-ansible-on-debian

# less: used by `ansible-config dump`
# python3-apt: used by `ansible-playbook --check`
ENV UBUNTU_CODENAME=jammy
RUN \
  apt-get update && \
  apt-get install \
    --assume-yes \
    --no-install-recommends \
    less \
    make \
    # npm \
    pipx \
    python3-apt \
    tini && \
  rm \
    --recursive \
    --force \
    /var/lib/apt/lists/*

ENV HOME=/home/me
RUN \
  mkdir --parents "${HOME}/app" && \
  chown \
    me:us \
    "${HOME}" && \
  chown \
    me:us \
    "${HOME}/app" && \
  ln --symbolic "${HOME}/app" /app

###########
# As `me` #
###########
USER me
WORKDIR /app

# RUN \
#   sudo npm install --global npm@latest \
#   sudo npm install --global dclint

RUN \
  pipx ensurepath && \
  pipx install --include-deps ansible==12.3 && \
  pipx install --include-deps ansible-dev-tools==26.1 && \
  pipx inject ansible-dev-tools ansible
  # eval '"$(register-python-argcomplete pipx)"' \
  #   >> "${HOME}/.bash_profile"

ENV SHELL=/bin/bash

ENTRYPOINT ["/usr/bin/tini", "--"]
