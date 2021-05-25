#!/bin/bash
#
# Make an image of the running gold master instance.
if [ -r "/etc/profile.d/aws-apitools-common.sh" ]; then
  . /etc/profile.d/aws-apitools-common.sh
fi

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

if [ -z "$INSTANCE_ID" ]; then
  echo "Querying AWS to determine gold master instance."
  # find the gold master instance
  INSTANCE_ID=$($AWS ec2 describe-instances --filters "Name=tag:Name,Values=tomcat-gold-master" "Name=instance-state-name,Values=running" | jq -r '.Reservations[].Instances[].InstanceId')
fi

if [ -z "$INSTANCE_ID" ]; then
  echo "Unable to determine gold master instance ID, exiting."
  exit 1
fi

# create the image, optionally taking IMAGE_INDEX as the first command-line argument
if [ -z "$1" ]; then
  echo "No image index provided, incrementing existing max index."
  IMAGE_INDEX=$($AWS ec2 describe-images --owners self | jq -r '.Images | map(select(.Name | startswith("tomcat-master-"))) | sort_by(.CreationDate) | last | .Name | ltrimstr("tomcat-master-")')
  let IMAGE_INDEX++
else
  IMAGE_INDEX="$1"
  echo "Setting image index to ${IMAGE_INDEX}."
fi

if [ -z "$IMAGE_INDEX" ]; then
  echo "Unable to determine image index, exiting."
  exit 1
fi

IMAGE_NAME="tomcat-master-${IMAGE_INDEX}"

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

TERMINATED_INSTANCE_ID=$($AWS ec2 terminate-instances --instance-ids $INSTANCE_ID | jq -r '.TerminatingInstances[].InstanceId')
echo "Terminating instance ${TERMINATED_INSTANCE_ID}."

# save state for the next script
cat > "$STATE" <<STATE
IMAGE_ID=$IMAGE_ID
STATE
