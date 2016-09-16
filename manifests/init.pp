# Class: rk_tomcat
# ===========================
#
# Deploy the Runkeeper Tomcat platform onto an instance.
#
# Parameters
# ----------
#
# * `mode`
# This module is to be used in both phases of a two-phase platform automation
# process.  The "provision" phase starts with an otherwise unmodified Amazon
# Linux instance and ends when that instance is ready to be imaged as a gold
# master AMI, _i.e._ all the customizations that are not application-specific
# have been applied.  The "deploy" phase starts with an instance cloned from a
# gold master AMI and ends when that instance is ready to be imaged as a
# release AMI, _i.e._ all application-specific customizations have been
# applied, one or more applications have been deployed, and new instances
# cloned from the AMI will come up in production-ready state without any
# additional intervention.
# Valid values are "provision" and "deploy" (the default).
#
# Examples
# --------
#
# @example
#    class { 'rk_tomcat':
#      mode => "provision",
#    }
#
# Authors
# -------
#
# Steve Huff <shuff@runkeeper.com>
#
# Copyright
# ---------
#
# Copyright 2015 FitnessKeeper Inc., unless otherwise noted.
#
# This code is released under the [MIT License](http://opensource.org/licenses/MIT).
#
class rk_tomcat (
  $stack ,
  $mode = 'deploy',
) {
  validate_re($mode, '^(provision|deploy)$')

  if ( $mode == 'provision' ) {
    class { 'rk_tomcat::fonts': }

    class { 'rk_tomcat::java':
      before => Class[rk_tomcat::tomcat],
    }
  }

  class { 'rk_tomcat::tomcat': }

  if ( $mode == 'deploy' ) {
    class { 'rk_tomcat::deploy':
      require => Class[rk_tomcat::tomcat],
    }
  }

  # common dependencies
  class { '::wget': }
}
