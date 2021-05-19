# rk_tomcat::deploy
#
class rk_tomcat::deploy (
  $artifacts,
  $aws_keys,
  $catalina_home,
  $cloudant_host,
  $cloudant_user,
  $cloudant_password,
  $logdna_tokens,
  $newrelic_enabled,
  $redis_pushnotif_host,
  $redis_queue_host,
  $redis_pushnotif_db,
  $redis_queue_db,
  $redis_port,
  $s3_path,
  $save_crash_dumps,
  $stack,
  $staging_instance,
  $tomcat_svc,
  $warname,
) {

  case $staging_instance {
    /loadtest/: {
      $cloudant_suffix  = "-loadtest"
      $log_identifiers  = $artifacts.map |$pair| { $pair[0] }
      $log_identifier   = "loadtest-${log_identifiers[0]}"
      $queue_identifier = 'loadtest'
      $tier             = 'loadtest'
      $newrelic_env     = 'loadtest'
      $conf_tier        = 'stage'
      $platform_env     = 'STAGE'
      $build_job_name   = 'STAGING - Build'
      $jenkins_stack    = 'rk-prod-app'
    }
    /^stage/: {
      $cloudant_suffix  = "-${staging_instance}"
      $log_identifiers  = $artifacts.map |$pair| { $pair[0] }
      $log_identifier   = "$staging_instance-${log_identifiers[0]}"
      $queue_identifier = $staging_instance
      $tier             = 'staging'
      $newrelic_env     = 'staging'
      $conf_tier        = 'stage'
      $platform_env     = 'STAGE'
      $build_job_name   = 'STAGING - Build'
      $jenkins_stack    = 'rk-prod-app'
    }
    '': {
      $cloudant_suffix  = ''
      $log_identifiers  = $artifacts.map |$pair| { $pair[0] }
      $log_identifier   = $log_identifiers[0]
      $queue_identifier = ''
      $tier             = 'production'
      $newrelic_env     = 'production'
      $conf_tier        = 'production'
      $platform_env     = 'PRODUCTION'
      $build_job_name   = "PRODUCTION - Build"
      $jenkins_stack    = 'rk-prod-app'
    }
    default: {
      fail("Unable to parse staging_instance parameter '${staging_instance}'.")
    }
  }

  validate_bool($save_crash_dumps)

  # Postgres
  $postgres = lookup('rk_tomcat::deploy::postgres', { 'value_type' => Hash })
  $postgres_resources = $postgres.map |$key,$values| {
    {
      'name'      => $values[name],
      'url'       => "jdbc:postgresql://${values[host]}:${values[port]}/${values[db]}${values[opts]}",
      'username'  => $values[user],
      'password'  => $values[password],
      'maxactive' => $values[max_conn],
      'maxidle'   => $values[max_conn],
    }
  }

  # LogDNA
  $logdna_applogs_token = $logdna_tokens['applogs']

  # Redis
  $redis_pushnotif_uri = "redis://${redis_pushnotif_host}:${redis_port}/${redis_pushnotif_db}"
  $redis_queue_uri = "redis://${redis_queue_host}:${redis_port}/${redis_queue_db}"

  # SQS
  $sqs_access_key = $aws_keys['sqs']['access_key']
  $sqs_secret_key = $aws_keys['sqs']['secret_key']

  File {
    ensure => 'present',
    owner  => 'tomcat',
    group  => 'tomcat',
    mode   => '0640',
  }

  Exec {
    path      => "${catalina_home}/bin:/usr/bin:/bin:/usr/sbin:/sbin",
    logoutput => 'on_failure',
  }

  file { 'deployBuild.sh':
    path    => "${catalina_home}/bin/deployBuild.sh",
    content => template('rk_tomcat/deployBuild.sh.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0750',
  } ->

  file { 'CloudantConfiguration.conf':
    path    => "${catalina_home}/conf/CloudantConfiguration.conf",
    content => template('rk_tomcat/CloudantConfiguration.conf.erb'),
  } ->

  file { 'logbackInclude.xml':
    path    => "${catalina_home}/conf/logbackInclude.xml",
    content => template('rk_tomcat/logbackInclude.xml.erb'),
  } ->

  file { 'MessageQueueingConfiguration.conf':
    path    => "${catalina_home}/conf/MessageQueueingConfiguration.conf",
    content => template('rk_tomcat/MessageQueueingConfiguration.conf.erb'),
  } ->

  file { 'PushNotificationTrackingConfiguration.conf':
    path    => "${catalina_home}/conf/PushNotificationTrackingConfiguration.conf",
    content => template('rk_tomcat/PushNotificationTrackingConfiguration.conf.erb'),
  } ->

  file { 'server.xml':
    path    => "${catalina_home}/conf/server.xml",
    content => template('rk_tomcat/server.xml.erb'),
  } ->

  file { 'tomcat.conf':
    path    => "${catalina_home}/conf/tomcat.conf",
    content => template('rk_tomcat/tomcat.conf.erb'),
  }

  # cron job to save Tomcat crash dumps
  $ensure_crash_dump_cron = $save_crash_dumps ? {
    true    => 'present',
    default => 'absent',
  }

  cron::job { 'saveCrashDump':
    ensure   => $ensure_crash_dump_cron,
    command  => '/usr/local/bin/saveCrashDump.rb',
    hour     => '*',
    minute   => '*',
    month    => '*',
    weekday  => '*',
    user     => 'root',
  }

  class { 'rk_tomcat::kinesis': }

  class { 'rk_tomcat::newrelic::deploy': }

  class { 'rk_tomcat::rsyslog::deploy':
    application_tag => $log_identifier
  }

  class { 'rk_tomcat::auth': }
}
