#!/bin/bash
source config.env

echo "Finding EC2 Instances..."
INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$INSTANCE_NAME" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text)

if [ ! -z "$INSTANCE_IDS" ]; then
  echo "Terminating Instances..."
  aws ec2 terminate-instances --instance-ids $INSTANCE_IDS

  echo "Waiting for instances to terminate..."
  aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS
fi

echo "Deleting Security Group..."
SG_ID=$(aws ec2 describe-security-groups \
  --group-names "$SECURITY_GROUP_NAME" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

if [[ "$SG_ID" != "None" && "$SG_ID" != "" ]]; then
  aws ec2 delete-security-group --group-id "$SG_ID"
else
  echo "Security group not found or already deleted."
fi

echo "Deleting Key Pair..."
aws ec2 delete-key-pair --key-name "$KEY_PAIR_NAME"
rm -f ${KEY_PAIR_NAME}.pem

echo "Deleting S3 Buckets..."
BUCKETS=$(aws s3api list-buckets \
  --query "Buckets[?starts_with(Name, '$BUCKET_PREFIX')].Name" \
  --output text)

for bucket in $BUCKETS; do
  echo "Deleting bucket: $bucket"
  aws s3 rb s3://$bucket --force
done

echo "Cleanup completed successfully!"