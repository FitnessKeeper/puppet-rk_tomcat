#!/bin/bash

# sanity checking
if [ -z "$ASG_NAME" ]; then
  echo "No ASG_NAME variable found, exiting."
  exit 1
fi
if [ -z "$INSTANCE_REFRESH_ID" ]; then
  echo "No INSTANCE_REFRESH_ID variable found, exiting."
  exit 1
fi

#track the instance refresh until complete
while :
do
  refresh=$(aws autoscaling describe-instance-refreshes \
    --auto-scaling-group-name "$ASG_NAME" \
    --instance-refresh-ids "$INSTANCE_REFRESH_ID")
  
  status=$(echo "$refresh" | jq -r '.InstanceRefreshes[0].Status')
  percentcomplete=$(echo "$refresh" | jq -r '.InstanceRefreshes[0].PercentageComplete')
  statusreason=$(echo "$refresh" | jq -r '.InstanceRefreshes[0].StatusReason')

  case $status in
    Pending)
      echo "Instance Refresh Status $status"
      sleep 30
      ;;
    InProgress | Cancelling | RollbackInProgress)
      echo "Instance Refresh Status $status ($percentcomplete% Complete), $statusreason"
      sleep 30
      ;;
    Successful)
      echo "Instance refresh completed successfully"
      exit 0
      ;;
    *)
      echo "Instance refresh did not complete successfully, status: $status, reason: $statusreason"
      exit 1
      ;;
  esac
done
