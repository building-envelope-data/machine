# syntax=docker/dockerfile:1.17
# check=error=true
# Available versions are listed on https://hub.docker.com/r/docker/dockerfile

FROM debian:bookworm

ARG GROUP_ID
ARG USER_ID

# Create non-root user to run commands in (see https://medium.com/@mccode/processes-in-containers-should-not-run-as-root-2feae3f0df3b)
# id --user --name ${USER_ID} 2>/dev/null
RUN \
  apt-get update && \
  apt-get install \
    --assume-yes \
    --no-install-recommends \
    adduser \
    sudo && \
  existing_user_name="$(getent passwd ${USER_ID} 2>/dev/null | cut --delimiter=: --fields=1)" && \
  if test -n "${existing_user_name}"; then deluser "${existing_user_name}"; fi && \
  existing_group_name="$(getent group ${GROUP_ID} 2>/dev/null | cut --delimiter=: --fields=1)" && \
  if test -n "${existing_group_name}"; then delgroup "${existing_group_name}"; fi && \
  addgroup --system --gid ${GROUP_ID} us && \
  adduser --system --home /home/me --uid ${USER_ID} --ingroup us me && \
  usermod --append --groups sudo me && \
  echo "me ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/me && \
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

ENV UBUNTU_CODENAME=jammy
RUN \
  apt-get update && \
  apt-get install \
    --assume-yes \
    --no-install-recommends \
    gnupg2 \
    less \
    make \
    pipx \
    tini && \
  rm \
    --recursive \
    --force \
    /var/lib/apt/lists/*

ENV HOME=/home/me
RUN \
  mkdir --parents ${HOME}/app && \
  chown \
    me:us \
    ${HOME} && \
  chown \
    me:us \
    ${HOME}/app && \
  ln --symbolic ${HOME}/app /app

###########
# As `me` #
###########
USER me
WORKDIR /app

RUN \
  pipx ensurepath && \
  pipx install --include-deps ansible && \
  pipx install --include-deps ansible-dev-tools && \
  pipx inject ansible-dev-tools ansible
  # eval '"$(register-python-argcomplete pipx)"' \
  #   >> ${HOME}/.bash_profile

ENV SHELL=/bin/bash

ENTRYPOINT ["/usr/bin/tini", "--"]
