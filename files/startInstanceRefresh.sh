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

#start the instance refresh
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name "$ASG_NAME" \
  --desired-configuration "{\"LaunchTemplate\":{\"LaunchTemplateName\":\"$SLOT_NAME\",\"Version\":\"\$Default\"}}" \
  --query 'InstanceRefreshId' \
  --output text