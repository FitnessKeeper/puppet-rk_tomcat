# Wrapper class for consul
# == Class: rk_tomcat::consul
#
class rk_tomcat::consul (
  $datacenter,
  $tag_key,
  $version,
  ) {
  class { '::consul':
    version  => "$version",
    service_enable => true,
    service_ensure => false,
    config_hash => {
      'data_dir'             => '/opt/consul',
      'datacenter'           => "$datacenter",
      'log_level'            => 'INFO',
      'retry_join'           => ["provider=aws tag_key=$tag_key tag_value=true"],
      'enable_script_checks' => true,
      'ports'                => { 'dns' => 53 },
      'raft_protocol'        => '3',
    }
  }

  file { '/opt/consul/node-id':
    ensure  => absent,
    require => Class['consul']
  }
}
