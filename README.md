# Debian Production Machine

The network of databases
[buildingenvelopedata.org](https://www.buildingenvelopedata.org/) is based on
databases and one metabase. This repository can be used to set up the machine
either to deploy
a [database](https://github.com/building-envelope-data/database) or to deploy
the [metabase](https://github.com/building-envelope-data/metabase).

The machine has two ext4 disks namely one root disk running [Debian
bookworm](https://www.debian.org/releases/bookworm/) and one initially empty
data disk. The data disk is partitioned, formatted, and mounted to `/app/data`
as described below. There is a Debian user `cloud` with superuser privileges
and a corresponding group `cloud`. The machine setup is mostly done by running
the Ansible playbook `./setup.yaml` with `make setup` as the user `cloud`. The
machine runs two instances of the application, one for staging in
`/app/staging` and the other for production in `/app/production`. Using
[NGINX](https://nginx.org) as reverse proxy it directs traffic coming from the
sub-domain `staging` or `www` to the staging or production instance.

Note that the
[network of databases buildingenvelopedata.org](https://www.buildingenvelopedata.org)
and the
[TestLab Solar Facades product-data server](https://www.solarbuildingenvelopes.com)
both run on machines provided by
[Fraunhofer Cloud](https://cloudportal.fraunhofer.de) and some of the set-up
information below may still be Fraunhofer Cloud specific. If you find that that
is the case, please
[report it on GitHub](https://github.com/building-envelope-data/machine/issues/new)
and we will try to generalize it.

This project follows the
[GitHub Flow](https://guides.github.com/introduction/flow/), in particular, the
branch `main` is always deployable.

## Setting up the machine

1. If there is a firewall, configure it such that it allows secure shell (ssh)
   access on port 22. And if there are explicit port forwardings, forward the
   public port 22 to port 22.
1. Enter a shell on the production machine using `ssh` as the user `cloud`.
1. Install
   [GNU Make](https://www.gnu.org/software/make/),
   [Git](https://git-scm.com),
   [pipx](https://github.com/pypa/pipx),
   [scsitools](https://packages.debian.org/bookworm/scsitools),
   [GNU Parted](https://www.gnu.org/software/parted/manual/parted.html), and
   [e2fsprogs](https://packages.debian.org/bookworm/e2fsprogs)
   by running `sudo apt-get install make git pipx scsitools parted e2fsprogs`, and
   install
   [Ansible](https://www.ansible.com) and
   [Ansible Development Tools](https://github.com/ansible/ansible-dev-tools)
   by running
   `pipx install --include-deps ansible && pipx install --include-deps ansible-dev-tools && pipx inject ansible-dev-tools ansible`.
1. Create a symbolic link from `/app` to `~` by running
   `sudo ln --symbolic ~ /app`.
1. Change into the app directory by running `cd /app`.
1. Clone the repository by running
   `git clone git@github.com:building-envelope-data/machine.git`.
1. Change into the clone by running `cd ./machine`.
1. Prepare the machine environment by running
   `cp ./.env.sample ./.env && chmod 600 ./.env` (or
   `cp ./.env.buildingenvelopedata.sample ./.env && chmod 600 ./.env` or
   `cp ./.env.solarbuildingenvelopes.sample ./.env && chmod 600 ./.env`) and
   adapt the `.env` file as needed for example inside `vi ./.env` or `nano ./.env`. The `.env` variables
   - `HOST` is the domain name without sub-domain;
   - `PRODUCTION_SUBDOMAIN`, `STAGING_SUBDOMAIN`, `TELEMETRY_SUBDOMAIN` are the
     sub-domains of the production instance `/app/production`, staging instance
     `/app/staging`, and the telemetry services `logs`, and `metrics`. Note
     that none of these sub-domains can be empty. The reverse proxy NGINX
     redirects requests to `${HOST}` without a sub-domain to such with the
     sub-domain `${PRODUCTION_SUBDOMAIN}`. If the domain name is too long, then
     NGINX will fail to start, for example, with the error message `"Could not build the server_names_hash. You should increase server_names_hash_bucket_size."` and it becomes necessary to [tune the
     `server_names_hash_max_size` or `server_names_hash_bucket_size`
     directives](https://nginx.org/en/docs/http/server_names.html#optimization),
     in the above example just increase `server_names_hash_bucket_size` to the
     next power of two;
   - `EXTRA_HOST` is an extra domain name for which the TLS certificate fetched
     from [Let's Encrypt](https://letsencrypt.org) shall also be valid apart
     from `${HOST}`, `${PRODUCTION_SUBDOMAIN}.${HOST}`,
     `${STAGING_SUBDOMAIN}.${HOST}`, and `${TELEMETRY_SUBDOMAIN}.${HOST}` (it
     is used in `./init-tls.sh`);
   - `HTTP_PORT` and `HTTPS_PORT` are the HTTP and HTTPS ports on which the
     NGINX reverse proxy is listening;
   - `PRODUCTION_HTTP_PORT` or `STAGING_HTTP_PORT` is the HTTP port on which the
     production instance `/app/production` or staging instance `/app/staging`
     is listening;
   - `MONITOR_HTTP_PORT`, `LOGS_HTTP_PORT`, or `METRICS_HTTP_PORT` is the HTTP
     port on which the monitoring utility [Monit](https://mmonit.com/monit/),
     the logs service
     [VictoriaLogs](https://github.com/VictoriaMetrics/VictoriaLogs), and the
     metrics service
     [VictoriaMetrics](https://github.com/VictoriaMetrics/VictoriaMetrics) is
     listening;
   - `TELEMETRY_GPRC_PORT` or `TELEMETRY_HTTP_PORT` is the
     [gPRC](https://grpc.io) and HTTP port on which the observability pipelines
     tool [Vector](https://vector.dev) listens for [OpenTelemetry
     Protocol](https://opentelemetry.io/docs/specs/otlp/) data;
   - `EMAIL_ADDRESS` is the email address of the person to be notified when
     there is some system-administration issue (for example
     [Monit](https://mmonit.com/monit/) sends such notifications)
   - `SMTP_HOST` and `SMTP_PORT` are host and port of the message transfer
     agent to be used to send emails through the Simple Mail Transfer
     Protocol (SMTP);
   - `NETWORK_INTERFACE` is the network interface to monitor with Monit (list
     all with `./tools.mk network-interfaces` or simply `ip link`);
1. Prepare your remote controls GNU Make and Docker Compose by running
   - `ln --symbolic ./docker-compose.production.yaml ./docker-compose.yaml` and
   - `ln --symbolic ./docker.mk ./Makefile`.
1. If there is a firewall, configure it such that it allows the protocol TCP
   for ports 80 and 443.
1. If the HTTP and HTTPS port configured in `.env` are not 80 and 443, then the
   public ports 80 and 443 must be forwarded to the configured ports
   `${HTTP_PORT}` and `${HTTPS_PORT}`.
1. Format and mount hard disk for data to the directory `/app/data` as follows:
   1. Create the directory `/app/data` by running `mkdir /app/data`.
   1. Scan for the data disk by running `./tools.mk scan`.
   1. Figure out its name and size by running `lsblk`, for example, `sdb` and
      `50G`, and use this name and size instead of `sdx` and `XG` below.
   1. Partition the hard disk `/dev/sdx` by running
      `sudo parted --align=opt /dev/sdx mklabel gpt`
      and
      `sudo parted --align=opt /dev/sdx mkpart primary 0 XG`
      or, if the command warns you that resulting partition is not properly
      aligned for best performance: 1s % 4096s != 0s,
      `sudo parted --align=opt /dev/sdx mkpart primary 4096s XG`.
      If the number of sectors, 4096 above, is not correct, consult
      [How to align partitions for best performance using parted](https://rainbow.chard.org/2013/01/30/how-to-align-partitions-for-best-performance-using-parted/)
      for details on how to compute that number.
   1. Format the partition `/dev/sdx1` of hard disk `/dev/sdx` by running
      `sudo mkfs.ext4 -L data /dev/sdx1`
      and mount it permanently by adding
      `UUID=XXXX-XXXX-XXXX-XXXX-XXXX /app/data ext4 errors=remount-ro 0 1`
      to the file `/etc/fstab` and running
      `sudo mount --all && sudo systemctl daemon-reload`,
      where the UUID is the one reported by
      `sudo blkid | grep /dev/sdx1`.
      Note that to list block devices and whether and where they are
      mounted run `lsblk` and you could mount partitions temporarily by running
      `sudo mount /dev/sdx1 /app/data`.
   1. Change owner and group of `/app/data` to user and group `cloud` by
      running `sudo chown cloud:cloud /app/data`.
   1. Create the directory `/app/data/backups` by running
      `mkdir /app/data/backups`.
1. Set-up everything else with Ansible by running `make setup`.
1. Before you try to interact with Docker in any way, log-out and log-in again
   such that the system knows that the user `cloud` is in the group `docker`
   (this was taken care of by Ansible). You could for example exit the SSH
   session by running `exit` and start a fresh one as you did in the beginning.
   If you do not do that, you will encounter a permission denied error. For
   example, when running `docker ps` the error reads "Got permission denied
   while trying to connect to the Docker daemon socket at
   unix:///var/run/docker.sock: Get
   "http://%2Fvar%2Frun%2Fdocker.sock/v1.24/containers/json": dial unix
   /var/run/docker.sock: connect: permission denied".
1. Fetch Transport Security Protocol (TLS) certificates from [Let's
   Encrypt](https://letsencrypt.org) used for HTTPS by running
   `./init-tls.sh` (if you are unsure whether the script will work, set the
   variable `staging` inside that script to `1` for a trial run).
1. Start all services by running `make dotenv pull up`. On subsequent
   deployments just run `make deploy` to also rerun `setup`.
1. Continue with the second step of
   [setting up a Debian production machine of the metabase](https://github.com/building-envelope-data/metabase?tab=readme-ov-file#setting-up-a-debian-production-machine)
   or
   [setting up a Debian production machine of a product-data database](https://github.com/building-envelope-data/database?tab=readme-ov-file#setting-up-a-debian-production-machine).

## Upgrading the system

Security upgrades are installed automatically and unattendedly by
[`unattended-upgrades`](https://packages.debian.org/search?keywords=unattended-upgrades)
as configured in the Ansible playbook `./setup.yaml`. Non-security upgrades should
be done weekly by running `./maintenance.mk upgrade`. If the command asks you
to reboot, then please do so and run `./maintenance.mk end` afterwards. Only
run the possibly destructive command `./maintenance.mk dist-upgrade` when you
know what you are doing. See the entries `upgrade` and `dist-upgrade` in the
`apt-get` manual `man apt-get`.

To install security upgrades in Docker services, redeploy the production and
staging environments as described in
[Deploying a release of the metabase](https://github.com/building-envelope-data/metabase#deploying-a-release)
or
[Deploying a release of the database](https://github.com/building-envelope-data/database#deploying-a-release).
Rebuilding the image and recreating the services are the important steps here,
which can also be done in `/app/production` and `/app/staging` by running
`./deploy.mk begin-maintenance services end-maintenance`.

Additionally, to keep HTTPS, that is, HTTP over TLS, secure, regularly fetch
SSL configuration and Diffie–Hellman parameters from certbot as explained in
[issue #5](https://github.com/building-envelope-data/machine/issues/5).

Before the installed version of Debian reaches its end of life, upgrade to the
next major version. Enter a shell on the production machine using `ssh`. Print
which Debian version is installed by running `lsb_release --all`. Consult [Long
Term Support](https://wiki.debian.org/LTS) for when it reaches its end of life.
If it is to be soon, then [perform an
upgrade](https://www.debian.org/releases/stable/i386/release-notes/ch-upgrading.html).
Our machines run Debian 12 "Bookworm" which reaches its end of life on June
30th, 2028.

## Periodic jobs

In the Ansible playbook `./setup.yaml`, periodic jobs are set-up.

- System logs are are vacuumed daily keeping logs of the latest seven days.
- The Transport Layer Security (TLS) certificates used by HTTPS, that is, HTTP
  over TLS, are renewed daily if necessary.
- The database is backed-up daily keeping the latest seven backups. To do so,
  the production GNU Make target `backup` of the
  [`metabase`'s `deploy.mk`](https://github.com/building-envelope-data/metabase/blob/develop/deploy.mk)
  and
  [`database`'s `deploy.mk`](https://github.com/building-envelope-data/database/blob/develop/deploy.mk)
  are used.
- The docker system is pruned daily without touching anything that is younger
  than one day.
- Logs in `/var/log/` are rotated daily by the Debian-default Cron job
  `/etc/cron.daily/logrotate`. It's configured in `/etc/logrotate.conf`.

If a job fails, Cron sends an email to `${EMAIL_ADDRESS}` set in `./.env`.

## Logs

For logs of periodic jobs see above.

- Docker services logs are collected and stored by `journald` and can be
  followed by running `make logs`.
- Docker daemon logs are collected and stored by `journald` and can be
  followed by running `./logs.mk daemon`.
- Cron logs are collected and stored by `journald` and can be
  followed by running `./logs.mk cron`.
- Monitoring logs are collected and stored by `journald` and can be
  followed by running `./logs.mk monit`.
- SMTP client logs are collected and stored by `journald` and can be
  followed by running `./logs.mk msmtp`.
- Certbot logs are written to `/certbot/logs/*.log.*` and the latest log-files
  can be followed by running `./logs.mk certbot`.

## Troubleshooting

If the website is not reachable, then check whether the reverse proxy is up and
healthy by running `make list`.

- If not, identify the reason by studying the logs printed by `make logs`, fix
  any issues if necessary, and [redeploy the reverse
  proxy](#deploying-the-latest-version).
- If yes, check whether the reverse proxy receives requests by studying the
  logs printed by `make logs`.
  - If not, there may be an issue with the mapping
    of the URL to the server managed by
    [Fraunhofer ISE](https://www.ise.fraunhofer.de)
    (you can find out more as elaborated in
    [Linux troubleshooting commands: 4 tools for DNS name resolution problems](https://www.redhat.com/sysadmin/DNS-name-resolution-troubleshooting-tools))
    or an issue with the firewall settings or port forwardings configured in
    the network settings for the public IP addresses in the
    [Fraunhofer cloudportal](https://cloudportal.fraunhofer.de) (the firewall
    must allow the protocol TCP for ports 80 and 443 and the public ports 80
    and 443 must be forwarded to the HTTP and HTTPS ports configured in `.env`;
    note that for secure shell access port 22 must be allowed and forwarded to
    22).
  - If yes, the reverse proxy may not be configured properly, for example, the
    ports of the production and staging web servers may not match the ones
    configured in `.env` in `/app/production` and `/app/staging`, or the
    production and staging web servers may be down or unhealthy, which you can
    check by running `make list` in `/app/production` and `/app/staging` and
    troubleshoot as elaborated in the READMEs of the
    [metabase](https://github.com/building-envelope-data/metabase) and
    [database](https://github.com/building-envelope-data/database) projects.

## Deploying the latest version

1. Fetch and checkout the latest version by running `git fetch` and
   `git checkout --force main`.
1. Deploy the new version by running `make deploy`.
1. Check that everything works by scanning the output of `make logs`.
