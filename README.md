# Nextcloud in a FreeBSD jail via Ansible
Setting up Nextcloud requires a number of steps which become tedious if repeated time and again. Ansible playbooks are a great way to automate much of the process, especially when frequent updates of the jails or data migration is a use case.

## References
In the preparation of this ansible playbook, the following web reference have been invaluable:
 - [John Ramsden's tutorial of Nextcloud in a jail](https://ramsdenj.com/2017/06/05/nextcloud-in-a-jail-on-freebsd.html)
 - [Vermaden's tutorial on Nextcloud in a jail](https://vermaden.wordpress.com/2018/04/04/nextcloud-13-on-freebsd/)
 - [Dan Langille's description of bootstrapping FreeBSD for Ansible](http://dan.langille.org/2013/12/22/creating-a-new-ansible-node/)
 - [OpenZFS discussion on ZFS tuning parameters for databases](http://open-zfs.org/wiki/Performance_tuning)
 - [Nextcloud's official documentation](https://docs.nextcloud.com/) and its [Forums](https://help.nextcloud.com/)

## Scope
This set of files plays at the intersection of _recommended_ by Nextcloud and _headache-free_ as by status quo of FreeBSD upstream support (e.g. available packages, base system, etc).
Currently supported environment (i.e. tested with):
 - FreeBSD 11.2-RELEASE-pX (including base system security updates)
 - Nextcloud 13
 - MySQL 5.6 (reason for this particular one is that the upstream package of Nextcloud 13 depends on mysql56-client. Accepting this saves us the trouble to install conflicting packages when using MariaDB ans subsequent messing with the pkg database. Might change in the future.)
 - PHP 7.2
 - Nginx 1.14 (using php-fhm)
 - Redis 4.0

The default location for mutable data is `/data/mysql` for the database and `/data/nextcloud` for Nextcloud's files. This should make migration, rollback and backup easier.

This set of files does (currently) not deal with advanced topics like database replication with multiple nodes or load balancing.

## Preparation
A few things should be prepared in advance before the playbook can run:
 - Get an SSL certificate for the webserver. This configuration will provide Nextcloud via https only. One popular way to get a certificate these days is via [letsencrypt.org](https://letsencrypt.org/). A self-signed certificate can be obtained via `openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout nginx.key -out nginx.crt`. Adapt to your needs and put in the `secrets/` folder.
 - Come up with reasonably secure database passwords for the root user and the Nextcloud admin accout. Create a `secrets/dbcred.yml` with the following YAML variables:
   - `db_rootpw: <DatabaseRootPasswordHere>`
   - `db_ncuser: <NextcloudDBtablesAdminUserHere>`
   - `db_ncpass: <NextcloudDBtablesAdminPasswordHere>`
 - Create a `secrets/server.yml` with the following YAML variables for insertion into `nginx.conf`:
   - `server_name: <your.server.here.tld>`
 - Create a jail running FreeBSD 11.2-RELEASE-pX using your favourite method.
   - Ensure sshd is running in the jail and the jail is reachable.
   - Create an ansible user who is a member of the wheel group, e.g. via `pw useradd -n ansible -s /bin/sh -m -d /usr/home/ansible -G wheel`
   - Install python: `pkg install -y python`
 - Have a hosts file for ansible containing
   ```
   [nextcloud]
   <JailIPhere>
   ```

### Optional
A few recommended steps during preparation:
- Create separate ZFS data sets for storing the actual *data* of your Nextcloud (databases and user file spaces). This makes migration of the data into a different / updated jail very convenient and is in line with the mainstream idea to separate 'immutable' containers from the data they generate. While on it:
- Create optimized ZFS data sets for the database. On [http://open-zfs.org/wiki/Performance_tuning
](http://open-zfs.org/wiki/Performance_tuning) there are recommended options for ZFS filesystems for several databases which should be set **when creating the filesystem**. The playbook and the deployed mysql configuration use separate directories for `mysql/innodb` and `mysql/innodb-log` to allow for this tuning.

## Run
Running `ansible-playbook -i YourHostsFile freebsd_nextcloud_bootstrap.yml` should result in a jail running all the necessary services. If not, please find the bug and report it. Pull requests are always welcome.

## Manual post-config
Unfortunately, Nextcloud generates some configuration on-the-fly and browser-based.
Thus this is not ansible-automated (yet) and **manual post-config is necessary**.
1. Point your web browser to https://YourJailHere. The Nextcloud title page should load and displays a form where the following parameters must be entered:
  1. Nextcloud admin account user name: The user name of the Nextcloud admin profile that you are just about to create.
  2. Nextcloud admin account password: This user's password (**don't use the database admin password here**)
  3. Data folder: Don't use the defaults. Instead point it to `/data/nextcloud`
  4. Database user name: The user name that you have used for db_ncuser in dbcred.yml
  5. Database user password: The password dbcred_ncpass in dbcred.yml
  6. Database Name: `nextcloud`
  7. Database host and port: `localhost`
2. After entering everything and clicking "Finish setup" , the browser will complain about broken redirects and leave you with an error message. **Don't worry about this and continue with the next steps.**
3. Log into the jail. We will see that Nextcloud has already generated a partially working configuration in `/usr/local/www/nextcloud/config/config.php` which we will fix in the next steps.
4. Fix broken redirects: FreeBSD's `/usr/ports/UPDATING` added an entry on 2018-04-04 with a solution for this problem. As `root`, execute `cd /usr/local/www/nextcloud; su -m www -c "php ./occ config:import < /usr/local/share/nextcloud/fix-apps_paths.json"`. Now, reloading the page in the browser should work and present Nextcloud's file manager, logged in as the admin user. On the title bar, a warning may be displayed "There were problems with code integrity check." Again, **don't worry about this and continue with the next steps.**
5. Additional Nextcloud apps, such as calendar, tasks etc. (which were installed during the bootstrap process if you have not edited `freebsd_nextcloud_bootstrap.yml`) only work after enabling the _dav app_ which is disabled by default. To enable this, as `root` execute `cd /usr/local/www/nextcloud; su -m www -c "php ./occ app:enable dav"`
6. Perform a Nextcloud routine maintenance job to ensure nothing is broken. As `root`, execute `cd /usr/local/www/nextcloud; su -m www -c "php ./occ maintenance:repair"`. There should not be any major problems, so exit the maintenance mode. As `root`, execute `cd /usr/local/www/nextcloud; su -m www -c "php ./occ maintenance:mode --off"`.
7. Click on the warning "There were problems with code integrity check." on the top of the title bar. It will open a page listing security and setup warnings and highlight in red "Some files have not passed the integrity check." Click _Rescan..._ at the end of this line. After page reloading, this warning disappears. The only remaining warning is about the lack of a caching service which is addressed next.
8. Enable redis caching. Using your favourite editor (importing a JSON config snipped using occ as in the previous steps does not seem to work in this case), open `/usr/local/www/nextcloud/config/config.php` and insert the content of `/usr/local/share/nextcloud/memcache.redis.php` just before the last line (which should be just a closing parenthesis and a semicolon):
```
...
<inserted from memcache.redis.php here>
);
```
9. Reloading the page (or navigating to ProfileBubbleOnTheRightOfTheTitieBar -> Settings -> Administration -> Basic settings), the section "Security & setup warnings" should now display "All checks passed".
10. Activate additional apps: Navigating to ProfileBubbleOnTheRightOfTheTitieBar -> Apps will open the overview of available apps. The ones installed during the bootstrap are already available and can be activated simply by click "Enable" in the respective row. For instance, enabling "Calendar" causes a calendar icon to appear in the Nextcloud title bar and the app can be used right away.

Now everything should work as intended. Have fun with Nextcloud in a jail.

## Variant: PostgreSQL instead of MySQL

### Scope

The purpose of this variant is to use PostgreSQL 10 instead of MySQL.

### Preparation

- The PostgreSQL variant assumes that a custom pkg repository exists where the build-time configuration for Nextcloud includes the PGSQL OPTION. If it is not clear how to do that, refer to the FreeBSD handbook and the `poudriere` documentation.
It is necessary to place a file `custom_pkg.yml` into `secrets/` containing this:
```
custom_repo:
  key: NameOfPublicKeyFileUsedForRepositorySigning
  url: URLtoCustomPackageRepository
```
The file referenced to above by key is expected to reside in the `secrets/` folder as well.
- It also assumes that there is a login class `postgres` in `/etc/login.conf` as described in the installation message of postgresql10-server.

### Caveats
- In the "manual post-config" section, for "Database host and port", `/tmp` must be entered to make the php database connector use the unix socket provided by the PostgreSQL server. Note that this does not match the Nextcloud documentation and may change in future, but for now it apparently works.
- The OpenZFS tuning guide on [http://open-zfs.org/wiki/Performance_tuning](http://open-zfs.org/wiki/Performance_tuning) recommends seperate file systems for `/data/postgres/base` and `/data/postgres/pg_wal`.
They **must not** exist before the initial creation of the database, otherwise the creation procedure fails.
Thus, if specially tuned zfs datasets are used, this has to be migrated manually after initdb completes.

## Open points for future revisions
- [ ] Memcache JSON file for config.php such that `cd /usr/local/www/nextcloud; su -m www -c "php ./occ config:import < /usr/local/share/nextcloud/memcache_redis.json"` works
- [ ] Idempotent ansible bits such that the section _Manual post-config_ is completely covered by a playbook
