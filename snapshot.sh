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

# AWS KEYS
# S3 SETTINGS - if not provided, assume IAM role is used
# s3 encryption (sse)

s3_bucket=${S3_BUCKET?"You must include a bucket name"}
s3_prefix=${S3_PREFIX-"scheduled-"}
s3_acl=${S3_ACL-private}
aws_access_key=${S3_ACCESS_KEY-none}
aws_secret_key=${S3_SECRET_KEY-none}

dump_root=${DUMP_FOLDER-"/tmp"}

if [[ $aws_access_key != "none" && $aws_secret_key != "none" ]]; then
  # Setup the credentials
  export AWS_ACCESS_KEY_ID=$aws_access_key
  export AWS_SECRET_ACCESS_KEY=$aws_secret_key
  export AWS_DEFAULT_REGION=us-east-1
fi

pgdump_format=${DUMP_FORMAT-custom}
pgdump_jobs=${THREADS-1}

# TODO: before we bother with the whole backup, check the creds ??

backup_timestamp=$(date -u +%Y%m%d%H%M%S)

pg_dump $conn_url --format=$pgdump_format --verbose --jobs=$pgdump_jobs --no-owner --file=$dump_root/snapshot.dump

if [ $? -ne 0 ]; then
  echo "ERROR: pg_dump failed, unable to continue"
  exit $?
fi

echo "Uploading snapshot to S3"
aws s3 cp $dump_root/snapshot.dump s3://${s3_bucket}/${s3_prefix}${backup_timestamp}.dump --acl $s3_acl
s3_ret=$?

rm -f $dump_root/snapshot.dump

if [ $s3_ret -eq 0 ]; then
  echo "Successfully uploaded '/${s3_prefix}${backup_timestamp}.dump' to S3!"
else
  echo "ERROR: Failed to upload to S3"
fi

exit $s3_ret
