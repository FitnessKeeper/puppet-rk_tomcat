# rk_tomcat::tomcat
#
class rk_tomcat::tomcat (
  $hosts,
  $catalina_home,
  $logdir,
  $postgres_driver,
  $postgres_tls,
  $tomcat_instance,
  $tomcat_pkg,
  $tomcat_native_pkg,
  $tomcat_svc,
  $tomcat_user,
  $tomcat_group,
  $tomcat_jars_context_skip,
) {
  validate_array($tomcat_jars_context_skip)

  # Host file management
  validate_hash($hosts)
  create_resources('host', $hosts)

  # Postgres
  $postgres_driver_jarfile = "${postgres_driver}.jar"

  validate_bool($postgres_tls)
  case $postgres_tls {
    true : {
      $postgres_certdir_state = 'directory'
      $postgres_certdir_mode = '0600'
    }
    default : {
      $postgres_certdir_state = 'absent'
      $postgres_certdir_mode = undef
    }
  }

  File {
    ensure => 'present',
    owner  => $tomcat_user,
    group  => $tomcat_group,
    mode   => '0640',
    notify => Service[$tomcat_svc],
  }

  # install Tomcat package
  tomcat::install { '/usr/share/tomcat7':
      source_url => 'https://www-us.apache.org/dist/tomcat/tomcat-7/v7.0.109/bin/apache-tomcat-7.0.109.tar.gz',
  } ->

  tomcat::instance { 'default':
    manage_service  =>  false,
    catalina_home   => $cataline_home,
  } ->

  class { 'rk_tomcat::newrelic::provision': } ->

  file { 'postgres_driver':
    path   => "${catalina_home}/lib/${postgres_driver_jarfile}",
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => "puppet:///modules/rk_tomcat/${postgres_driver_jarfile}",
  } ->

  file { 'catalina.properties':
    path    => "${catalina_home}/conf/catalina.properties",
    mode    => '0664',
    content => template('rk_tomcat/catalina.properties.erb'),
  } ->

  file { 'provision.sh':
    path   => '/root/provision.sh',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  } ->

  file { 'deploy.sh':
    path   => '/root/deploy.sh',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/rk_tomcat/deploy.sh',
  } ->

  file { 'saveCrashDump.rb':
    path    => '/usr/local/bin/saveCrashDump.rb',
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => template('rk_tomcat/saveCrashDump.rb.erb')
  } ->

  file { $logdir:
    ensure => 'directory',
    group  => 'root',
    mode   => '0751',
  } ->

  # apr for performance
  package { $tomcat_native_pkg:
    ensure => present,
  } ->

  ::tomcat::service { $tomcat_instance:
    use_jsvc       => false,
    use_init       => true,
    service_name   => $tomcat_svc,
    service_ensure => 'stopped',
    service_enable => true,
  }

  # configure rsyslog to log to DataHub
  class { 'rk_tomcat::rsyslog': }

  # configure OS limits
  class { 'rk_tomcat::limits': }

  # install Goss
  class { 'rk_tomcat::goss': }

}
