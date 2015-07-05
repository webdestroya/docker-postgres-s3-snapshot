
# postgres-s3-snapshot

[![](https://badge.imagelayers.io/webdestroya/postgres-s3-snapshot:latest.svg)](https://imagelayers.io/?images=webdestroya/postgres-s3-snapshot:latest 'Get your own badge on imagelayers.io')

This container can be used to easily manage Elasticsearch snapshots.

## Environment Variables

* `ELASTICSEARCH_URL` *(default: `http://elasticsearch-9200.service.consul:9200`)*
  * The URL to reach your Elasticsearch server.
  * **NOTE**: This must be the **entire** hostname or IP. Hostnames that expect a search domain to be added will not work.
* `ESS_ABORT_IF_EMPTY` *(default: true)*
  * This will abort the snapshot process if there are no indices on the server.
  * This is useful if you just bootstrapped a cluster, and want to restore before doing any backups. The repository will still be created, but no snapshots will be created until there are indices on the server.
* `ESS_CREATE_IF_MISSING` *(defaut: false)*
  * If this is `true` and the snapshot repository does not exist, then attempt to create it. See the [Repository Auto-Creation](#repository-auto-creation) section for more information.
* `ESS_MAX_SNAPSHOTS` *(defaut: 0)*
  * The maximum number of snapshots to allow. Set to `0` to disable entirely.
  * Note: Only snapshots with a `scheduled-` prefix will be counted and deleted. All other snapshots will not count against this limit.
* `ESS_REPO_NAME` **required**
  * The name of the repository to create snapshots under.
* `ESS_WAIT_FOR_COMPLETION` *(default: true)*
  * Whether the execution should wait until the snapshot has been created before exiting.


#### Repository Auto-Creation

If `ESS_CREATE_IF_MISSING` is set to `true` then the following are relevant:

* `ESS_REPO_TYPE` **required**
  * The repository type field. Common ones include `fs` and `s3`.
* `ESS_REPO_SETTINGS_<SETTING>` *optional*
  * Add an environment variable per setting key to build the repository creation payload.
  * If there are no `ESS_REPO_SETTINGS_*` variables found, then the settings hash will be `{}`.

An example creation payload construction:

```text
ESS_CREATE_IF_MISSING=true
ESS_REPO_TYPE=s3
ESS_REPO_SETTINGS_BUCKET=mybucket
ESS_REPO_SETTINGS_COMPRESS=true
ESS_REPO_SETTINGS_BASE_PATH=/path/to/put/snapshots
```

Would result in a payload of:

```json
{
  "type":"s3",
  "settings": {
    "bucket": "mybucket",
    "compress": "true",
    "base_path": "/path/to/put/snapshots"
  }
}
```

For more details about repository creation, see the [Elasticsearch documentation](https://www.elastic.co/guide/en/elasticsearch/reference/1.6/modules-snapshots.html#_repositories)

## Usage
This is best used with a timer and service combination in your cluster.

```
# postgres-s3-snapshot.timer
[Unit]
Description=PostgreSQL Scheduled Snapshot Timer

[Timer]
OnCalendar=hourly
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
  -e ELASTICSEARCH_URL=http://elasticsearch-9200.service.consul:9200 \
  -e ESS_REPO_NAME=s3_repository \
  -e ESS_MAX_SNAPSHOTS=100 \
  -e ESS_WAIT_FOR_COMPLETION=true \
  webdestroya/elasticsearch-snapshot

[Install]
WantedBy=multi-user.target

[X-Fleet]
Conflicts=%p.service
```

## Useful Plugins
This tool was built primarily for the [cloud-aws](https://github.com/elastic/elasticsearch-cloud-aws) Elasticsearch plugin.
