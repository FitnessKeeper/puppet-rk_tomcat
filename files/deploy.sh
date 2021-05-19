#!/bin/bash -l
#
LOGGER='logger -t [CLOUDINIT] -p user.info'

if [[ "${USER}" -ne 0 ]]; then
  $LOGGER "$0 must be run as root."
  exit 1
fi

if [ -r "/etc/profile.d/aws-apitools-common.sh" ]; then
  . /etc/profile.d/aws-apitools-common.sh
fi

INSTANCE_ID=$(ec2-metadata -i | awk '{print $2}')
# determine AWS region
AZ=$(ec2-metadata -z | awk '{print $2}')
REGION=$(echo "$AZ" | sed 's/[[:alpha:]]$//')

AWS="aws --region $REGION"

INSTANCE_NAME=$($AWS ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCE_ID}" | jq -r '.Tags | map(select(.Key == "Name"))[] | .Value')

LOGGER="logger -t ${INSTANCE_NAME} -p daemon.info"

$LOGGER "Deploying..."

$LOGGER "Copying secrets..."
for i in 'secrets' 'secrets-common'; do
  touch "rk_tomcat/data/${i}.yaml" \
    && chmod 600 "rk_tomcat/data/${i}.yaml"
done
$AWS s3 cp "s3://rk-devops-${REGION}/secrets/secrets-common.yaml" "rk_tomcat/data/secrets-common.yaml"
$AWS s3 cp "s3://rk-devops-${REGION}/secrets/instances/${INSTANCE_ID}.yaml" "rk_tomcat/data/secrets.yaml"

if [ ! -r "rk_tomcat/data/secrets.yaml" ]; then
  $LOGGER "Populate the secrets.yaml file and then run $0 again."
  exit 0
fi

cd rk_tomcat

$LOGGER "Running Puppet agent..."
PUPPET_LOGDIR=/var/log/puppet
PUPPET=$(which puppet 2>/dev/null || echo '/usr/local/bin/puppet')
$PUPPET apply \
  --hiera_config "data/hiera.yaml" \
  --modulepath "/etc/puppetlabs/code/modules" \
  --logdest "${PUPPET_LOGDIR}/deploy.log" \
  -e 'class { "rk_tomcat": mode => "deploy" }'

if [ -r "${PUPPET_LOGDIR}/deploy.log" ]; then
  $LOGGER "Uploading deploy log to S3..."
  $AWS s3 cp "${PUPPET_LOGDIR}/deploy.log" "s3://rk-devops-${REGION}/jenkins/logs/${INSTANCE_NAME}/deploy.log"
else
  $LOGGER "No deploy log found."
fi

$LOGGER "Disabling Puppet agent..."
$PUPPET resource service puppet ensure=stopped enable=false

# now download the WARs
APPLICATION_VERSION=___REPLACE_ME_APPVERSION___
PROMOTED_VERSION=___REPLACE_ME_PROMVERSION___
$LOGGER "Deploying application build $APPLICATION_VERSION (promoted $PROMOTED_VERSION)..."
/usr/share/tomcat/bin/deployBuild.sh $PROMOTED_VERSION

GOSS=$(which goss)
if [ -n "$GOSS" ]; then
  $LOGGER "Testing configuration with Goss..."
  GOSS_OUT=/root/goss.out
  GOSS_OPTS='--gossfile=/root/goss.json'
  cd /root
  echo "### BEGIN GOSS - $(date)" > $GOSS_OUT
  $GOSS $GOSS_OPTS render | $GOSS $GOSS_OPTS validate >> $GOSS_OUT
  echo "### END GOSS - $(date)" >> $GOSS_OUT

  if [ -r "$GOSS_OUT" ]; then
    cat $GOSS_OUT
    $LOGGER "Uploading Goss test results to S3..."
    $AWS s3 cp $GOSS_OUT "s3://rk-devops-${REGION}/jenkins/tests/${INSTANCE_ID}"
  else
    $LOGGER "No Goss results found!  Not uploading."
  fi
else
  $LOGGER "Goss not installed, skipping tests."
fi

$LOGGER "Removing semaphore..."
$AWS s3 rm "s3://rk-devops-${REGION}/jenkins/semaphores/${INSTANCE_ID}" 2>/dev/null || true

$LOGGER "Cleaning up..."
$AWS s3 rm "s3://rk-devops-${REGION}/secrets/instances/${INSTANCE_ID}.yaml"
cd ..
# rm -rf rk_tomcat
# rm -rf /etc/puppetlabs/code/modules/*
# yum clean all

$LOGGER "Deploy complete."
