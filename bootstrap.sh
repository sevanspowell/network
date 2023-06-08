#!/usr/bin/env bash

set -euo pipefail

if ! aws s3api head-bucket --bucket "sbennett-infra" 2>/dev/null; then
  echo "S3 state bucket doesn't exists, creating..."
  aws s3api create-bucket \
    --bucket sbennett-infra \
    --acl private \
    --region ap-southeast-2 \
    --create-bucket-configuration "LocationConstraint=ap-southeast-2"
fi

aws s3api put-bucket-versioning \
  --bucket sbennett-infra \
  --versioning-configuration "MFADelete=Disabled,Status=Enabled"

if ! aws dynamodb describe-table --table sbennett-infra-db --region ap-southeast-2 1>/dev/null 2>/dev/null; then
  echo "DynamoDB state-locking table doesn't exists, creating..."
  aws dynamodb create-table \
    --table-name sbennett-infra-db \
    --key-schema "AttributeName=LockID,KeyType=HASH" \
    --attribute-definitions "AttributeName=LockID,AttributeType=S" \
    --provisioned-throughput "ReadCapacityUnits=5,WriteCapacityUnits=5" \
    --region ap-southeast-2
fi

# Build base AMI
nix build .#nixosConfigurations.base.config.system.build.amazonImage
aws s3 cp ./result/*.vhd s3://sbennett-infra/amis/base.vhd
