# AGENTS.md - Agent Coding Guidelines

This repository is an **infrastructure/deployment project** for managing production machines using Docker, Docker Compose, and Ansible. It follows GitHub Flow where `main` is always deployable.

## Build, Lint, and Validation Commands

### Local Development

```bash
# Full lint (dotenv, shell scripts, Docker Compose, Dockerfile)
make lint

# Auto-fix linting issues
make fix

# Format shell scripts and Dockerfile
make format

# Validate all configs (Ansible, Vector, Monit, MSMTP)
make --file ./tools.mk check

# Check .env file consistency
make dotenv

# Syntax-check Ansible playbook
make --file ./tools.mk syntax-ansible

# Lint Ansible
make --file ./tools.mk lint-ansible

# Fix Ansible linting issues
make --file ./tools.mk fix-ansible

# Dry-run Ansible playbook
make --file ./tools.mk dry-run-ansible

# Validate Vector configuration
make --file ./tools.mk validate-vector

# Syntax-check Monit
make --file ./tools.mk syntax-monit
```

**Note**: The tools in `./tools.mk`, `./maintenance.mk`, and `./logs.mk` can only be run within the shell entered via `make machine` (development environment).

### Docker Commands

```bash
# Deploy services (dotenv check + setup + pull + up)
make deploy

# Start services
make up

# Stop services
make down

# View logs
make logs SERVICE=<service_name>

# Enter shell in service
make shell SERVICE=<service_name>

# Enter machine container for debugging
make machine
```

### CI/CD (GitHub Actions)

The lint GitHub workflow (`.github/workflows/lint.yaml`) is currently disabled. Instead, this project relies on local linting with `make lint` and `make check` before pushing changes.

## Code Style Guidelines

### General Principles

- Keep configurations in YAML format
- Use descriptive names for variables and tasks
- Always use error handling (`set -o errexit -o errtrace -o nounset -o pipefail`)
- Group related configurations together

### Makefiles

- All Makefiles must include at the top:
  ```make
  SHELL := /usr/bin/env bash
  .SHELLFLAGS := -o errexit -o errtrace -o nounset -o pipefail -c
  MAKEFLAGS += --warn-undefined-variables
  ```
- Use self-documenting targets with `##` comments
- Default goal should be `help`

### Ansible Playbooks (`setup.yaml`)

- Use `ansible.builtin.` prefix for modules
- Always define `become: true` for privileged tasks
- Use handlers for services that need restarting
- Pre-task validation for required environment variables
- Follow naming pattern: `var_naming_pattern: "^[a-zA-Z_][a-zA-Z0-9_]*$"` (see `.ansible-lint`)

### Docker/Compose Files

- Services in alphabetical order
- Port definitions use double quotes: `ports: ["80:80"]`
- Use meaningful service names
- See `.dclintrc` for linter configuration

### Shell Scripts

- Must pass `shellcheck` validation
- Use `set -o errexit -o errtrace -o nounset -o pipefail`
- Use `#!/usr/bin/env bash` shebang
- Use `$()` for command substitution, not backticks
- Quote variables: `"$VAR"` not `$VAR`

### Environment Files (`.env`)

- Must pass `dotenv-linter` validation
- Use `UPPER_SNAKE_CASE` for variable names
- Keep alphabetically ordered
- Include all required variables from `.env.sample`
- Never commit secrets - use `.env` in `.gitignore`

### YAML Files

- Use 2-space indentation
- Use `|` for multi-line strings where appropriate
- Always use explicit tags for implicit types
- Keep files alphabetically sorted where applicable

### Error Handling

- Always use `set -o errexit -o pipefail` in shell scripts
- Use Ansible's `failed_when` and `changed_when` for complex conditions
- Validate inputs with `ansible.builtin.assert` before processing
- Use `when:` conditions for environment-specific tasks

### Naming Conventions

- **Variables**: `UPPER_SNAKE_CASE` (environment, Ansible vars), `lower_snake_case` (local vars in shell)
- **Files**: `kebab-case` for Docker files, `snake_case` for scripts
- **Ansible tasks**: `verb_noun` format (e.g., `ensure_package`, `create_directory`)
- **Services**: lowercase, descriptive names

### Git Workflow

- Branch from `main`
- Make small, focused commits
- PRs trigger MegaLinter automatically
- `main` is always deployable

## File Structure

```
/home/simon/Projects/ise/machine/
├── setup.yaml              # Main Ansible playbook
├── docker.mk               # Docker/Make commands
├── tools.mk                # System tools
├── .env                    # Environment variables (not committed)
├── .env.*.sample           # Sample env files
├── docker-compose.*.yaml   # Docker Compose configs
├── Dockerfile.development # Docker image definition
├── nginx/                  # NGINX configuration templates
├── certbot/                # TLS certificate handling
└── .github/workflows/     # GitHub Actions
```

## Testing

This project does not have traditional unit tests. Instead:

1. **Syntax validation**: `make --file ./tools.mk syntax-ansible`, `make --file ./tools.mk syntax-monit` (run inside `make machine`)
2. **Lint checks**: `make lint`, `make --file ./tools.mk check` (run inside `make machine`)
3. **Dry-run**: `make --file ./tools.mk dry-run-ansible` (runs Ansible in check mode, run inside `make machine`)
4. **Manual testing**: Use `make machine` to enter debug container

## Additional Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [dotenv-linter](https://dotenv-linter.github.io/)
