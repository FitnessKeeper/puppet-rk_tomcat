# rk_tomcat::rsyslog
#
class rk_tomcat::rsyslog(
  $datahub_host,
  $datahub_port,
) {

  File {
    ensure => present,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
  }

  # LogDNA wants GnuTLS support
  package { "rsyslog-gnutls":
    ensure => present,
  }

  # default logging to DataHub
  file { '/etc/rsyslog.d':
    ensure => directory,
    mode   => '0755',
  }

  file { "datahub-default":
    path    => '/etc/rsyslog.d/50-datahub-default.conf',
    content => template('rk_tomcat/datahub-default.conf.erb'),
  }

  file { "logdna-ca":
    path   => '/etc/pki/tls/certs/ld-root-ca.crt',
    source => 'puppet:///modules/rk_tomcat/rsyslog/ld-root-ca.crt',
  }
}
