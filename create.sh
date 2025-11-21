#!/bin/bash
source config.env

echo "Checking AWS CLI..."
if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI not installed!"
  exit 1
fi

echo "Validating AWS credentials..."
aws sts get-caller-identity >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Invalid AWS credentials!"
  exit 1
fi

echo "Creating Key Pair..."
if aws ec2 describe-key-pairs --key-names "$KEY_PAIR_NAME" >/dev/null 2>&1; then
  echo "Key pair already exists."
else
  aws ec2 create-key-pair --key-name "$KEY_PAIR_NAME" \
       --query "KeyMaterial" --output text > ${KEY_PAIR_NAME}.pem
  chmod 400 ${KEY_PAIR_NAME}.pem
fi

echo "Creating Security Group..."
SG_ID=$(aws ec2 describe-security-groups \
        --group-names "$SECURITY_GROUP_NAME" \
        --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then
  SG_ID=$(aws ec2 create-security-group \
          --group-name "$SECURITY_GROUP_NAME" \
          --description "Task SG" \
          --output text)

  aws ec2 authorize-security-group-ingress \
      --group-id "$SG_ID" \
      --protocol tcp --port 22 --cidr 0.0.0.0/0
fi

echo "Launching EC2 Instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_PAIR_NAME" \
  --security-group-ids "$SG_ID" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
  --query "Instances[0].InstanceId" \
  --output text)

sleep 20

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

BUCKET_NAME="${BUCKET_PREFIX}-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME --region "$AWS_REGION"

echo "EC2 Public IP: $PUBLIC_IP"
echo "S3 Bucket: $BUCKET_NAME"
