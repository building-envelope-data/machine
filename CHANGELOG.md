# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Rely on new ansible features not available in the Debian-bookworm package archive --- delete the corresponding file in /etc/apt/sources.list.d/, remove ansible with `sudo apt remove ansible`, install pipx with `sudo apt install pipx && pipx ensurepath`, and reinstall ansible with `pipx install --include-deps ansible && pipx inject --include-deps --include-apps ansible python-debian ansible-dev-tools`
- Switch to the structured deb822 format for personal package archives in /etc/apt/sources.list.d/ --- you may need to remove ansible managed /etc/apt/sources.list.d/*.list files before running `make setup`
- Harden SSH daemon, in particular, allow *only* publickey authentication (for details see ./sshd_config.conf) --- make sure that you don't lock yourself out by running `make setup` and disconnecting without a secure SSH key (for example an ed25519 key) added to /home/cloud/.ssh/authorized_keys

[Unreleased]: https://github.com/building-envelope-data/database/compare/v1.0.0...HEAD
