#!/bin/bash

# sanity checking
if [ -z "$ASG_NAME" ]; then
  echo "No ASG_NAME variable found, exiting."
  exit 1
fi
if [ -z "$SLOT_NAME" ]; then
  echo "No SLOT_NAME variable found, exiting."
  exit 1
fi

#get the current desired capacity
currentcapacity=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-name "$ASG_NAME" \
    --query 'AutoScalingGroups[0].DesiredCapacity' \
    --output text)

#set the desired capacity to double the current amount
aws autoscaling set-desired-capacity --auto-scaling-group-name "$ASG_NAME" --desired-capacity $(($currentcapacity * 2))

echo $currentcapacity
