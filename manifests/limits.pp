# rk_tomcat::limits
#
class rk_tomcat::limits (
  $nofile,
) {
  limits::limits{'tomcat-nofile':
    ensure     => present,
    limit_type => 'nofile',
    both       => "$nofile",
    user       => '*',
  }

  # sysctl
  sysctl { 'fs.file-max':
    ensure  => present,
    value   => $nofile,
    comment => 'set max open files for Tomcat',
    target  => '/etc/sysctl.d/10-rk_tomcat.conf',
    apply   => false,
  }
}
