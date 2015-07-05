
# postgres-s3-snapshot

[![](https://badge.imagelayers.io/webdestroya/postgres-s3-snapshot:latest.svg)](https://imagelayers.io/?images=webdestroya/postgres-s3-snapshot:latest 'Get your own badge on imagelayers.io')

This container can be used to easily take snapshots of your Postgres database and upload them to Amazon S3

## Environment Variables


#### Database Connection Variables

* `DATABASE_URL`
  * A connection URI to access the database
  * Example: `postgres://user:password@host:5432/database`

Alternatively, you may provide the individual connection values:

* `DB_NAME` **required** - the database name
* `DB_USER` **required** - the username
* `DB_PASS` **required** - the password
* `DB_HOST` **required** - the hostname ONLY (do not include the port)
* `DB_PORT` *(default: 5432)*


#### S3 Settings

* `S3_BUCKET` **required**
* `S3_ACL` *(default: private)*
* `S3_PREFIX` *(default: `scheduled-`)*
  * If you want to prefix your snapshots and place them in a specific path, you may enter it here.
  * Prefixes MUST NOT start with a slash (`/`)
  * The backup timestamp will be appended to the prefix.

The easiest way to configure permissions is by using an IAM instance role, and granting the instance running the snapshot the ability to upload objects to the specified S3 bucket. If that is not possible, then you can provide your credentials using the following environment variables:

* `S3_ACCESS_KEY`
* `S3_SECRET_KEY`

#### Advanced Settings

* `DUMP_FOLDER` *(default: `/tmp`)*
  * This is the local folder where the temporary dumpfile will be written. After it is uploaded to S3, it will be deleted.
* `DUMP_FORMAT` *(default: custom)*
  * You can change the dump format used by `pg_dump`. If you are planning to use `pg_restore` to recover, you should stick with the default of `custom`.
* `THREADS` *(default: 1)*
  * The number of tables to dump concurrently. Increasing this will reduce backup time, but increase load on the server.


You can read a more detailed explanation about these options on the [pg_dump documentation](http://www.postgresql.org/docs/9.4/static/app-pgdump.html).

If your main docker location does not have enough space, you will need to change the `DUMP_FOLDER` variable and mount a host directory into your container. You should include `ExecStartPost=-/usr/bin/rm -f /host/folder/snapshot.dump` in your service file just in case something goes wrong.

**IMPORTANT**: If you mount a host folder, you are completely responsible for ensuring that two snapshot tasks are not accessing the same host folder at the same time. If a second instance starts changing the backup file while it is being uploaded or exported, bad things can happen.

## Usage
This is best used with a timer and service combination in your cluster.

```
# postgres-s3-snapshot.timer
[Unit]
Description=PostgreSQL Scheduled Snapshot Timer

[Timer]
OnCalendar=daily
Persistent=false

[Install]
WantedBy=multi-user.target

[X-Fleet]
Conflicts=%p.timer
MachineOf=%p.service
```

```
# postgres-s3-snapshot.service
[Unit]
Description=PostgreSQL Scheduled Snapshot
Requires=docker.service
After=docker.service

[Service]
TimeoutStartSec=0
Type=simple

ExecStartPre=-/usr/bin/docker pull webdestroya/postgres-s3-snapshot

ExecStart=/usr/bin/docker run --rm=true \
  -e DATABASE_URL=postgres://postgres:mypassword@superdb-server.ec2:5432/database \
  -e S3_BUCKET=postgres-snapshots \
  -e S3_PREFIX=cluster1-snaps/ \
  webdestroya/postgres-s3-snapshot

[Install]
WantedBy=multi-user.target

[X-Fleet]
Conflicts=%p.service
```

## Roadmap

* Ability to prune older snapshots based on date or based on total number
* Allow for S3 Server Side Encryption
