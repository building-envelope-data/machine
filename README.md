# Debian Production Machine

The machine has two ext4 disks namely one root disk running Debian and one
initially empty data disk.  The data disk is partitioned, formatted, and
mounted to `/app/data` as described below.  The machine setup is mostly done by
running the Ansible playbook `./local.yml` with `make setup`.  The machine runs
two instances of the application, one for staging in `/app/staging` and the
other for production in `/app/production`. Using [NGINX](https://nginx.org) as
reverse proxy it directs traffic coming from the sub-domain `staging` or `www`
to the staging or production instance.

This project follows the
[GitHub Flow](https://guides.github.com/introduction/flow/), in particular, the
branch `main` is always deployable.

## Setting up the machine
1. Install
   [GNU Make](https://www.gnu.org/software/make/),
   [scsitools](https://packages.debian.org/buster/scsitools),
   [GNU Parted](https://www.gnu.org/software/parted/manual/parted.html), and
   [e2fsprogs](https://packages.debian.org/buster/e2fsprogs)
   by running `sudo apt-get install make scsitools parted e2fsprogs`, and
   install [Ansible](https://www.ansible.com) as explained on
   [Installing Ansible on Debian](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible-on-debian).
1. Create a symbolic link from `/app` to `~` by running `sudo ln -s ~ /app`.
1. Format and mount hard disk for data to the directory `/app/data` as follows:
   1. Scan for the data disk by running `make scan`.
   1. Figure out its name and size by running `lsblk`, for example, `sdb` and
      `50G`, and use this name and size instead of `sdx` and `XG` below.
   1. Partition the hard disk `/dev/sdx` by running
      `sudo parted --align=opt /dev/sdx mklabel gpt`
      and
      `sudo parted --align=opt /dev/sdx mkpart primary 0 XG`
      or, if the command warns you that resulting partition is not properly
      aligned for best performance: 1s % 2048s != 0s,
      `sudo parted --align=opt /dev/sdx mkpart primary 2048s XG`.
      If the number of sectors, 2048 above, is not resported, consult
      https://rainbow.chard.org/2013/01/30/how-to-align-partitions-for-best-performance-using-parted/
      for details on how to compute that number.
   1. Format the partition `/dev/sdx1` of hard disk `/dev/sdx` by running
      `sudo mkfs.ext4 -L data /dev/sdx1`
      and mount it permanently by adding
      `UUID=XXXX-XXXX-XXXX-XXXX-XXXX /app/data ext4 errors=remount-ro 0 1`
      to the file `/etc/fstab` and running
      `sudo mount --all`,
      where the UUID is the one reported by
      `sudo blkid | grep /dev/sdx1`.
      Note that to list block devices and whether and where they are
      mounted run `lsblk` and you could mount partitions temporarily by running
      `sudo mount /dev/sdx1 /app/data`.
1. Change into the app directory by running `cd /app`.
1. Clone the repository by running
   `git clone git@github.com:ise621/machine.git`.
1. Change into the clone by running `cd ./machine`.
1. Prepare the machine environment by running `cp .env.sample .env` and adapt
   the `.env` file as needed for example inside `vi .env`.
1. Set-up everything else with Ansible by running `make setup`.

## Deploying the latest version
1. Fetch and checkout the latest version by running `git fetch` and
   `git checkout --force main`.
1. Update the set-up by running `make setup`.
1. Deploy the new version by running `make deploy`.
1. Check that everything works by scanning the output of `make logs`.