#!/bin/bash
#
# Make an image of the running deploy instance.

if [ -r ".env" ]; then
  . .env
else
  echo "Populate .env first."
  exit 1
fi

STATE='.state'

if [ -r "$STATE" ]; then
  . "$STATE"
fi

# determine region
if [ -z "$REGION" ]; then
  REGION=us-east-1
fi

AWS="aws --region $REGION"

# create the image
if [ -z "$INSTANCE_ID" ]; then
  echo "Querying AWS to determine deploy instance."
  GOLD_MASTER_AMI=$($AWS ec2 describe-images --owners self | jq -r '.Images | map(select(.Name | startswith("tomcat-master-"))) | sort_by(.CreationDate) | last | .ImageId')

  INSTANCE_DATA=$($AWS ec2 describe-instances --filters "Name=image-id,Values=${GOLD_MASTER_AMI}" "Name=instance-state-name,Values=running")
  INSTANCE_ID=$(echo "$INSTANCE_DATA" | jq -r '.Reservations[].Instances[].InstanceId')
else
  echo "Obtained deploy instance from state file."
  INSTANCE_DATA=$($AWS ec2 describe-instances --instance-ids "$INSTANCE_ID")
fi

IMAGE_NAME=$(echo "$INSTANCE_DATA" | jq -r '.Reservations[].Instances[].Tags | from_entries | .Name')
IMAGE_ID=$($AWS ec2 create-image --instance-id $INSTANCE_ID --name $IMAGE_NAME --reboot | jq -r '.ImageId')

if [ -z "$IMAGE_ID" ]; then
  exit 1
fi

echo "Creating image ${IMAGE_ID}..."

IMAGE_STATE='pending'
while [ "$IMAGE_STATE" = "pending" ]; do
  sleep 10
  IMAGE_STATE=$($AWS ec2 describe-images --image-ids $IMAGE_ID --owners self | jq -r '.Images[].State')
done
echo "Image ${IMAGE_ID} is ${IMAGE_STATE}."

if [ "$IMAGE_STATE" != 'available' ]; then
  echo "Image creation failed, exiting."
  exit 1
fi

# TERMINATED_INSTANCE_ID=$($AWS ec2 terminate-instances --instance-ids $INSTANCE_ID | jq -r '.TerminatingInstances[].InstanceId')
echo "Terminating instance ${TERMINATED_INSTANCE_ID}."

# save state for the next script
cat > "$STATE" <<STATE
IMAGE_ID=$IMAGE_ID
STATE
