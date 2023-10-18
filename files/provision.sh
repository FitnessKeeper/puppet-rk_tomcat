#!/bin/bash -l
#

# set up logging
LOGGER='logger -t [CLOUDINIT] -p daemon.info'

GEMHOME=/usr/local/share/gems

if [[ "${USER}" -ne 0 ]]; then
  $LOGGER "$0 must be run as root."
  exit 1
fi

# can't do much without jq
yum -y -q install jq || exit 1

if [ -r "/etc/profile.d/aws-apitools-common.sh" ]; then
  . /etc/profile.d/aws-apitools-common.sh
fi

INSTANCE_ID=$(ec2-metadata -i | awk '{print $2}')

# determine AWS region
AZ=$(ec2-metadata -z | awk '{print $2}')
REGION=$(echo "$AZ" | sed 's/[[:alpha:]]$//')

AWS="aws --region $REGION"

VPC_ID=$($AWS ec2 describe-instances --instance-ids ${INSTANCE_ID} | jq -r '.Reservations[].Instances[].VpcId')
VPC=$($AWS ec2 describe-tags --filters "Name=resource-id,Values=${VPC_ID}" | jq -r '.Tags | map(select(.Key == "Name"))[] | .Value')
INSTANCE_NAME=$($AWS ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCE_ID}" | jq -r '.Tags | map(select(.Key == "Name"))[] | .Value')

# log to DataHub
RSYSLOG_D='/etc/rsyslog.d'
if [ -d "$RSYSLOG_D" ]; then
  cat > "${RSYSLOG_D}/50-datahub-default.conf" <<RSYSLOG
# log to DataHub
#
*.info;mail.none;authpriv.none;cron.none                @@datahub.${VPC}.vpc.rkcloud.us:10000
RSYSLOG

  service rsyslog restart

  LOGGER="logger -t ${INSTANCE_NAME} -p daemon.info"
fi

$LOGGER "Provisioning..."

$LOGGER "Patching system..."
yum -y update

$LOGGER "Uninstalling upstream Puppet..."
yum -y erase puppet

$LOGGER "Installing utilities..."
yum -y install git

$LOGGER "Installing redhat-rpm-config"
yum -y install redhat-rpm-config

yum -y install java-17-amazon-corretto-devel

amazon-linux-extras install epel -y
amazon-linux-extras install tomcat9 -y
yum downgrade tomcat*9.0.76 -y
amazon-linux-extras install ruby2.6

cd ~

GIT_BRANCH=master
$LOGGER "Cloning Tomcat platform configuration (${GIT_BRANCH})..."
git clone -b $GIT_BRANCH https://github.com/FitnessKeeper/puppet-rk_tomcat.git rk_tomcat

$LOGGER "Copying secrets..."
# only copy secrets-common to gold master image
for i in 'secrets-common'; do
  touch "rk_tomcat/data/${i}.yaml" \
    && chmod 600 "rk_tomcat/data/${i}.yaml" \
    && $AWS s3 cp "s3://rk-devops-${REGION}/secrets/${i}.yaml" "rk_tomcat/data/${i}.yaml"
done

if [ ! -r "rk_tomcat/data/secrets-common.yaml" ]; then
  $LOGGER "Populate the secrets-common.yaml file and then run $0 again."
  exit 0
fi

cd rk_tomcat

$LOGGER "Configuring RubyGems..."
yum -y install ruby-devel glibc-devel gcc
cat > /root/.gemrc << 'GEMRC'
---
install: --nodocument --bindir /usr/local/bin
update: --nodocument --bindir /usr/local/bin
GEMRC

$LOGGER "Installing Bundler..."
gem install bundler

$LOGGER "Installing Puppet dependencies..."
mkdir -p /etc/puppetlabs/code/modules
export PUPPET_MODULE_DIR='/etc/puppetlabs/code/modules'
yum -y install augeas augeas-devel libxml2-devel

$LOGGER "Installing other gem dependencies..."
BUNDLE=$(which bundle 2>/dev/null || echo '/usr/local/bin/bundle')
$BUNDLE install --verbose

LIBRARIAN_PUPPET=$(which librarian-puppet 2>/dev/null || echo '/usr/local/bin/librarian-puppet')
$LIBRARIAN_PUPPET config path "$PUPPET_MODULE_DIR" --global
$LIBRARIAN_PUPPET install

ln -sf /root/rk_tomcat "${PUPPET_MODULE_DIR}/rk_tomcat"

$LOGGER "Running Puppet agent..."
PUPPET_LOGDIR=/var/log/puppet
mkdir -p "$PUPPET_LOGDIR"

PUPPET=$(which puppet 2>/dev/null || echo '/usr/local/bin/puppet')
$PUPPET apply \
  --hiera_config "data/hiera.yaml" \
  --modulepath "/etc/puppetlabs/code/modules" \
  --logdest "${PUPPET_LOGDIR}/provision.log" \
  --verbose --debug \
  -e 'class { "rk_tomcat": mode => "provision" }'

if [ -r "${PUPPET_LOGDIR}/provision.log" ]; then
  $LOGGER "Uploading provisioning log to S3..."
  $AWS s3 cp "${PUPPET_LOGDIR}/provision.log" "s3://rk-devops-${REGION}/jenkins/logs/${INSTANCE_NAME}/provision.log"
else
  $LOGGER "No provisioning log found."
fi

$LOGGER "Disabling Puppet agent..."
$PUPPET resource service puppet ensure=stopped enable=false

$LOGGER "Linking Tomcat homedir to CATALINA_HOME..."
ln -sf /usr/share/tomcat /home/tomcat


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

# masking tomcat updates in yum.conf
echo "exclude=tomcat*" >> /etc/yum.conf

$LOGGER "Removing semaphore..."
$AWS s3 rm "s3://rk-devops-${REGION}/jenkins/semaphores/${INSTANCE_ID}" 2>/dev/null || true

cd ..

$LOGGER "Provision complete."
