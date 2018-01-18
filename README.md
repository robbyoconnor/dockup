# Dockup

[![Docker Automated build](https://img.shields.io/docker/automated/robbyoconnor/dockup.svg)](https://hub.docker.com/r/robbyoconnor/dockup/)
[![Docker Stars](https://img.shields.io/docker/stars/robbyoconnor/dockup.svg)](https://hub.docker.com/r/robbyoconnor/dockup/)
[![Docker Pulls](https://img.shields.io/docker/pulls/robbyoconnor/dockup.svg)](https://hub.docker.com/r/robbyoconnor/dockup/)
[![](https://images.microbadger.com/badges/image/robbyoconnor/dockup.svg)](https://microbadger.com/images/robbyoconnor/dockup "Get your own image badge on microbadger.com")
[![](https://images.microbadger.com/badges/commit/robbyoconnor/dockup.svg)](https://microbadger.com/images/robbyoconnor/dockup "Get your own commit badge on microbadger.com")

This is based on [wetransform-os/dockup](https://github.com/wetransform-os/dockup), but uses a slimmer base image.

The overall image size is [51 MB compressed; 157 MB uncompressed](https://hub.docker.com/r/robbyoconnor/dockup/tags/) vs. [157 MB compressed; 388 MB uncompressed](https://hub.docker.com/r/wetransform/dockup/tags/)

Docker image to backup your Docker container volumes.

Why the name? Docker + Backup = Dockup

Instead of backing up volumes you can also run tasks that provide the files to be backed up. See the following projects as examples on building on Dockup for that purpose:

* [robbyoconnor/dockup-mongo](https://github.com/robbyoconnor/dockup-mongo) - Uses `mongodump` and `mongorestore` to backup and restore a MongoDB instance
* [mimicmobile/dockup-postgres](https://github.com/mimicmobile/dockup-postgres) - Uses `pg_dump` and `pg_restore` to backup and restore a PostgreSQL instance

# Usage

You have a container running with one or more volumes:

```
$ docker run -d --name mysql tutum/mysql
```

From executing a `$ docker inspect mysql` we see that this container has two volumes:

```
"Volumes": {
  "/etc/mysql": {},
  "/var/lib/mysql": {}
}
```

## Backup

Launch `dockup` container with the following flags:

```
$ docker run --rm \
--env-file .env \
--volumes-from mysql \
--name dockup robbyoconnor/dockup:latest
```

The contents of `.env` being something like:

```
AWS_ACCESS_KEY_ID=<key_here>
AWS_SECRET_ACCESS_KEY=<secret_here>
AWS_DEFAULT_REGION=us-east-1
BACKUP_NAME=mysql
PATHS_TO_BACKUP=/etc/mysql /var/lib/mysql
S3_BUCKET_NAME=docker-backups.example.com
S3_FOLDER=mybackups/
RESTORE=false
```

`dockup` will use your AWS credentials to create a new bucket with name as per the environment variable `S3_BUCKET_NAME`, or if not defined, using the default name `docker-backups.example.com`. The paths in `PATHS_TO_BACKUP` will be tarballed, gzipped, time-stamped and uploaded to the S3 bucket.

To place backups in a specific folder in the S3 bucket, provide it in the `S3_FOLDER` variable.
It should either be empty or hold a path and end with a slash.

For more complex backup tasks as dumping a database, you can optionally define the environment variables `BEFORE_BACKUP_CMD` and `AFTER_BACKUP_CMD`.

### Detect volumes

Instead of providing paths manually you can set the `PATHS_TO_BACKUP` to `auto`.
Using this setting the backup script will try to the detect the volumes mounted into the running backup container and include these into the backup archive.

### Scheduling (snapshots)

If you want `dockup` to run the backup as a cron task, you can set the environment variable `CRON_TIME` to the desired frequency, for example `CRON_TIME=0 0 * * *` to backup every day at midnight.

### Scheduling (intervals)

Alternatively if you would like `dockup` to run interval backups as cron jobs (hourly, daily, weekly and monthly), set the environment variable `CRON_INTERVALS` to `true`.  Interval backups are named `$BACKUP_NAME-<interval>.tar.gz` and will overwrite existing backups of the same interval name.  The real benefit of interval backups comes when you enable [versioning](https://docs.aws.amazon.com/AmazonS3/latest/user-guide/enable-versioning.html) and create [lifecycle](https://docs.aws.amazon.com/AmazonS3/latest/user-guide/create-lifecycle.html) rules to automatically delete older previous versions of your backups.

By default hourly backups are done every hour on the hour.  Daily backups are done at 3:30am, weekly on Monday at 3:00am and monthly on the 1st of each month at 2:30am.

You can specify when and if each backup will fire by setting any of the respective environment variables (`CRON_HOURLY`, `CRON_DAILY`, `CRON_WEEKLY` and `CRON_MONTHLY`) to the desired frequency.

For example, `CRON_WEEKLY=0 2 * * 0` would run the weekly backup at 2am on Sundays.

If you wish to disable any of the intervals, you can do so by setting the value to `#`.

### Retries

Sometimes creating the TAR archive may fail, often due to modifications to the files while `tar` is running.

If this happens very often, you should consider using a different option than creating TAR archives for backup.
The `BEFORE_BACKUP_CMD` and `AFTER_BACKUP_CMD` environment variables can help with that.

If this happens seldomly and you want to avoid a backup failing due to that, you can configure Dockup to retry creating the archive if it fails.
For that, use the following environment variables:

* **BACKUP_TAR_TRIES** - maximum number of tries for the backup (defaults to `5`)
* **BACKUP_TAR_RETRY_SLEEP** - number of seconds to wait between retries (defaults to `30`)


## Restore
To restore your data simply set the `RESTORE` environment variable to `true` - this will restore the latest backup from S3 to your volume. If you want to restore a specific backup instead of the last one, you can also set the environment variable `LAST_BACKUP` to the desired tarball name.

For more complex restore operations, you can define a command to be run once the tarball has been downloaded and extracted using the environment variable `AFTER_RESTORE_CMD`.

## Encryption

You can use GnuPG to encrypt backup archives and decrypt them again when you need to restore them.
You need a GnuPG public key for encryption and the corresponding private key for decryption.
Keep the private key safe (and secret), otherwise you will not be able to restore your backups.

For backup, the following environment variables need to be set:

* **GPG_KEYRING** - the location of the public keyring containing the public key you want to use for encryption
* **GPG_KEYNAME** - the user ID identifying the key

For restoring an encrypted file, the following environment variables need to be set:

* **GPG_KEYRING** - the location of the public keyring
* **GPG_SECRING** - the location of the secret keyring containing the private key you need for decryption
* **GPG_PASSPHRASE** - the passphrase needed to access the private key


## Notifications

To enable notifications for backups you can use the following environment variables:

* **NOTIFY_BACKUP_SUCCESS** - set to `true` to enable notifications on backup success
* **NOTIFY_BACKUP_FAILURE** - set to `true` to enable notifications on backup failure

**In addition, you need to configure a notification method.**

Currently supported are the following notifications methods:


### Slack

To configure Slack notifications you need to set at least the `NOTIFY_SLACK_WEBHOOK_URL` environment variable.
Create an *Incoming Webhook* as a new integration in Slack and put the Webhook URL in here.


## Local testing

There is a handy script `./test-backup.sh` you can use for local testing.
All you need is Docker and configuring your S3 connection.
For that purpose, copy `test-env.txt.sample` to `test-env.txt` and adapt the variables accordingly.

Optionally generate a GPG key for testing encryption/decryption using `./gen-test-key.sh`.
It will be automatically used when you execute `./test-backup.sh`.
If you want to test w/o encryption after generating the key, rn `./test-backup.sh --no-encryption`.


## A note on Buckets

> [Bucket naming guidelines](http://docs.aws.amazon.com/cli/latest/userguide/using-s3-commands.html):
> "Bucket names must be unique and should be DNS compliant. Bucket names can contain lowercase letters, numbers, hyphens and periods. Bucket names can only start and end with a letter or number, and cannot contain a period next to a hyphen or another period."

These rules are enforced in some regions.


[AWS S3 Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#s3_region)

| Region name               | Region         |
| ------------------------- | -------------- |
| US Standard               | us-east-1      |
| US West (Oregon)          | us-west-2      |
| US West (N. California)   | us-west-1      |
| EU (Ireland)              | eu-west-1      |
| EU (Frankfurt)            | eu-central-1   |
| Asia Pacific (Singapore)  | ap-southeast-1 |
| Asia Pacific (Sydney)     | ap-southeast-2 |
| Asia Pacific (Tokyo)      | ap-northeast-1 |
| South America (Sao Paulo) | sa-east-1      |


To perform a restore launch the container with the RESTORE variable set to true


![](http://s.tutum.co.s3.amazonaws.com/support/images/dockup-readme.png)
