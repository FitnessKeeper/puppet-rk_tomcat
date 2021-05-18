# rk_tomcat::goss
#
class rk_tomcat::goss (
  $consul_version,
  $version,
  $destination,
  $catalina_home,
  $font_pkgs,
  $postgres_driver,
  $tomcat_pkg,
  $tomcat_native_pkg,
  $tomcat_svc,
  $tomcat_user,
  $tomcat_group,
  $tomcat_logdir,
  $zulu_package,
  $zulu_version,
) {
  $zulu_split = split($zulu_version, '-')
  $zulu_version_goss = $zulu_split[0]

  wget::retrieve { "download_goss":
    source      => "https://github.com/aelsabbahy/goss/releases/download/${version}/goss-linux-amd64",
    destination => $destination,
  } ->

  file { $destination:
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    backup => false,
  } ->

  file { '/root/goss_provision.json':
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('rk_tomcat/goss_provision.json.erb'),
  } ->

  file { '/root/goss.json':
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('rk_tomcat/goss.json.erb'),
  }
}
