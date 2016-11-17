# Wrapper class for threatstack
class rk_tomcat::threatstack (
    $deploy_key,
){
  class { '::threatstack':
    deploy_key      => $deploy_key,
    configure_agent => false,
  }
  file { '/etc/cloud/cloud.cfg.d/99_threatstack.cfg':
    ensure  => file,
    content => epp('rk_tomcat/99_threatstack.cfg.epp', {'deploy_key' => $deploy_key}),
  }
}
