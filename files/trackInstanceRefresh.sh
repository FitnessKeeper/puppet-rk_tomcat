#!/bin/bash

# sanity checking
if [ -z "$ASG_NAME" ]; then
  echo "No ASG_NAME variable found, exiting."
  exit 1
fi
if [ -z "$ORIGINAL_CAPACITY" ]; then
  echo "No ORIGINAL_CAPACITY variable found, exiting."
  exit 1
fi

#track the scaling activity until complete
while :
do
  refresh=$(aws autoscaling describe-scaling-activites \
    --auto-scaling-group-name "$ASG_NAME" \
    --max-items 1)
  
  status=$(echo "$refresh" | jq -r '.Activities[0].StatusCode')
  percentcomplete=$(echo "$refresh" | jq -r '.Activities[0].Progress')

  case $status in
    WaitingForInstanceId | PreInService | InProgress | WaitingForELBConnectionDraining | MidLifecycleAction | WaitingForInstanceWarmup | WaitingForConnectionDraining)
      echo "Instance Refresh for $ASG_NAME Status $status ($percentcomplete% Complete)"
      sleep 30
      ;;
    Successful)
      echo "Instance Refresh for $ASG_NAME completed successfully"
      exit 0
      ;;
    *)
      echo "Instance Refresh for $ASG_NAME did not complete successfully, status: $status"
      exit 1
      ;;
  esac
done

#set the desired capacity to the original value
ws autoscaling update-auto-scaling-group --auto-scaling-group-name "$ASG_NAME" --desired-capacity $ORIGINAL_CAPACITY)
