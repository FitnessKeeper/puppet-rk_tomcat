# Wrapper class for threatstack
class rk_tomcat::threatstack (
    $deploy_key,
){
  # Disable auditd service so threatstack agent can have exclusive access to the audit socket
  service { 'auditd': 
    ensure => 'stopped',
    enable => false,
  }
  class { '::threatstack':
    deploy_key      => $deploy_key,
    configure_agent => false,
    disable_auditd => true,
  }
  file { '/etc/cloud/cloud.cfg.d/99_threatstack.cfg':
    ensure  => file,
    content => epp('rk_tomcat/99_threatstack.cfg.epp', {'deploy_key' => $deploy_key}),
  }
}
