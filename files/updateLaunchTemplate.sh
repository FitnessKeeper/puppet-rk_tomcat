#!/bin/bash

# sanity checking
if [ -z "$SLOT_NAME" ]; then
  echo "No SLOT_NAME variable found, exiting."
  exit 1
fi
if [ -z "$VERSION_DESCRIPTION" ]; then
  echo "No VERSION_DESCRIPTION variable found, exiting."
  exit 1
fi
if [ -z "$AMI_ID" ]; then
  echo "No AMI_ID variable found, exiting."
  exit 1
fi

#Create the launch template version
template_version=$(aws ec2 create-launch-template-version \
  --launch-template-name "$SLOT_NAME" \
  --version-description "$VERSION_DESCRIPTION" \
  --launch-template-data "{\"ImageId\":\"$AMI_ID\"}" \
  --source-version '$Default' \
  --query 'LaunchTemplateVersion.VersionNumber' \
  --output text)

# #Set the version as default
aws ec2 modify-launch-template \
  --launch-template-name "$SLOT_NAME" \
  --default-version $template_version
