#!/bin/bash
#
# Spin up an instance to make a new deploy image.
SCRIPTDIR=$(dirname $0)

if [ -r ".env" ]; then
  . .env
else
  echo "Populate .env first."
  exit 1
fi

STATE='.state'

# determine region
if [ -z "$REGION" ]; then
  REGION=us-east-1
fi

AWS="aws --region $REGION"

echo "Starting instance for '$BUILD_TARGET' image."

# look up resource IDs
BUILD_VPC_ID=$($AWS ec2 describe-vpcs --filters "Name=tag:Name,Values=${BUILD_VPC}" | jq -r '.Vpcs | last | .VpcId')
SG_FILTER=$(echo -n '.SecurityGroups | map({GroupName, GroupId}) | map(select(.GroupName | test("' && echo -n "^${BUILD_VPC}-${BUILD_SECURITY_GROUP}-.*$" && echo -n '")))[] | .GroupId')
BUILD_SECURITY_GROUP_ID=$($AWS ec2 describe-security-groups --filters "Name=vpc-id,Values=${BUILD_VPC_ID}" | jq -r "$SG_FILTER")
BUILD_SUBNET_ID=$($AWS ec2 describe-subnets --filters "Name=vpc-id,Values=${BUILD_VPC_ID}" "Name=tag:Name,Values=${BUILD_SUBNET}" | jq -r '.Subnets | last | .SubnetId')

# create instance
if [ -z "$GOLD_MASTER_AMI" ]; then
  if [ -z "$1" ]; then
    echo "Querying AWS to determine latest gold master image ID."
    GOLD_MASTER_AMI=$($AWS ec2 describe-images --owners self | jq -r '.Images | map(select(.Name | startswith("tomcat7-master-"))) | sort_by(.CreationDate) | last | .ImageId')
  else
    GOLD_MASTER_AMI="$1"
    echo "Using gold master image ID ${GOLD_MASTER_AMI} provided on command line."
  fi
else
  echo "Using gold master image ID ${GOLD_MASTER_AMI} provided in environment."
fi

INSTANCE_DATA=$($AWS ec2 run-instances \
  --image-id "$GOLD_MASTER_AMI" \
  --key-name "$BUILD_SSH_KEYPAIR" \
  --security-group-ids "$BUILD_SECURITY_GROUP_ID" \
  --instance-type "$BUILD_INSTANCE_TYPE" \
  --subnet-id "$BUILD_SUBNET_ID" \
  --iam-instance-profile "Name=${BUILD_PROFILE_NAME}" \
  --user-data file://files/bootstrap-deploy.sh)

INSTANCE_ID=$(echo $INSTANCE_DATA | jq -r '.Instances[].InstanceId')
sleep 5

# tag instance
IMAGE_INDEX=$($AWS ec2 describe-images --owners self | jq -r ".Images | map(select(.Name | startswith(\"tomcat7-${BUILD_TARGET}-\"))) | sort_by(.CreationDate) | last | .Name | ltrimstr(\"tomcat7-${BUILD_TARGET}-\")")
let IMAGE_INDEX++
$AWS ec2 create-tags --resources $INSTANCE_ID --tags "Key=Name,Value=tomcat7-${BUILD_TARGET}-${IMAGE_INDEX}"

echo "Creating instance ${INSTANCE_ID} from image ${GOLD_MASTER_AMI}."
INSTANCE_HOSTNAME=''

# wait for hostname
while [ -z "$INSTANCE_HOSTNAME" ]; do
  sleep 2
  INSTANCE_HOSTNAME=$($AWS ec2 describe-instances --instance-ids $INSTANCE_ID | jq -r '.Reservations[].Instances[].PrivateDnsName')

  if [ "$INSTANCE_HOSTNAME" = "null" ]; then
    INSTANCE_HOSTNAME=''
  fi
done

# wait for the instance to be up
INSTANCE_STATE=''
while [ "$INSTANCE_STATE" != 'running' ]; do
  sleep 2
  INSTANCE_STATE=$($AWS ec2 describe-instances --instance-ids $INSTANCE_ID | jq -r '.Reservations[].Instances[].State.Name')
done

echo "Instance ${INSTANCE_ID} available at ${INSTANCE_HOSTNAME}."

# save state for the next script
cat >"$STATE" <<STATE
INSTANCE_ID=$INSTANCE_ID
INSTANCE_HOSTNAME=$INSTANCE_HOSTNAME
STATE
