#!/bin/bash

conn_url=${DATABASE_URL-none}

if [[ $conn_url == "none" ]]; then
  # build the URL
  conn_db_name=${DB_NAME?"You must include a DATABASE_URL variable or ALL connection variables"}
  conn_db_user=${DB_USER?"You must include a DATABASE_URL variable or ALL connection variables"}
  conn_db_pass=${DB_PASS?"You must include a DATABASE_URL variable or ALL connection variables"}
  conn_db_host=${DB_HOST?"You must include a DATABASE_URL variable or ALL connection variables"}
  conn_db_port=${DB_PORT-5432}

  conn_url=$(printf "postgres://%s:%s@%s:%s/%s" $conn_db_user $conn_db_pass $conn_db_host $conn_db_port $conn_db_name)
fi

# If the connection url is "none", then build it from various env vars

# AWS KEYS
# S3 SETTINGS - if not provided, assume IAM role is used
# s3 encryption (sse)

s3_bucket=${S3_BUCKET?"You must include a bucket name"}
s3_prefix=${S3_PREFIX-}
s3_region=${S3_REGION-"us-east-1"}
aws_access_key=${S3_ACCESS_KEY-none}
aws_secret_key=${S3_SECRET_KEY-none}

if [[ $aws_access_key != "none" && $aws_secret_key != "none" ]]; then
  # Setup the credentials
  export AWS_ACCESS_KEY_ID=$aws_access_key
  export AWS_SECRET_ACCESS_KEY=$aws_secret_key
  export AWS_DEFAULT_REGION=$s3_region
fi

pgdump_format=${PGDUMP_FORMAT-custom}
pgdump_jobs=${THREADS-1}

echo "PREFIX: [$s3_prefix]"

exit 1
# number of jobs?

backup_timestamp=$(date -u +%Y%m%d%H%M%S)

pg_dump $conn_url --format=$pgdump_format --jobs=$pgdump_jobs --no-owner --file=/tmp/snapshot.dump

if [ $? -ne 0 ]; then
  echo "ERROR: pg_dump failed, unable to continue"
  exit $?
fi

aws s3 cp <localfile>

# upload file stream?
aws s3 cp - s3://mybucket/stream.txt



# obliterate file
# shred -u -v <file>
