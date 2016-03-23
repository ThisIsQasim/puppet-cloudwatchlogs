# == Class: cloudwatchlogs
#
# Configure AWS Cloudwatch Logs on Amazon Linux instances.
#
# === Variables
#
# [*state_file*]
#   State file for the awslogs agent.
#
# [*region*]
#   The region your EC2 instance is running in.
#
# === Examples
#
#  include '::cloudwatchlogs'
#
#  class { '::cloudwatchlogs': region => 'eu-west-1' }
#
# === Authors
#
# Danny Roberts <danny.roberts@reconnix.com>
# Russ McKendrick <russ.mckendrick@reconnix.com>
#
# === Copyright
#
# Copyright 2015 Danny Roberts & Russ McKendrick
#
class cloudwatchlogs (
  $state_file = $::cloudwatchlogs::params::state_file,
  $region     = $::cloudwatchlogs::params::region,
  $logs       = {}
) inherits cloudwatchlogs::params {

  validate_absolute_path($state_file)
  if $region {
    validate_string($region)
  }

  validate_hash($logs)
  create_resources('cloudwatchlogs::log', $logs)

  case $::operatingsystem {
    'Amazon': {
      package { 'awslogs':
        ensure => 'present',
      }

      concat { '/etc/awslogs/awslogs.conf':
        ensure         => 'present',
        owner          => 'root',
        group          => 'root',
        mode           => '0644',
        ensure_newline => true,
        warn           => true,
        require        => Package['awslogs'],
      }
      concat::fragment { 'awslogs-header':
        target  => '/etc/awslogs/awslogs.conf',
        content => template('cloudwatchlogs/awslogs_header.erb'),
        order   => '00',
      }

      service { 'awslogs':
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        hasstatus  => true,
        subscribe  => Concat['/etc/awslogs/awslogs.conf'],
      }
    }
    /^(Ubuntu|CentOS|RedHat)$/: {
      if ! defined(Package['wget']) {
        package { 'wget':
          ensure => 'present',
        }
      }

      exec { 'cloudwatchlogs-wget':
        path    => '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin',
        command => 'wget -O /usr/local/src/awslogs-agent-setup.py https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py',
        unless  => '[ -e /usr/local/src/awslogs-agent-setup.py ]',
        require => Package['wget'],
      }

      file { '/etc/awslogs':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
      } ->
      concat { '/etc/awslogs/awslogs.conf':
        ensure         => 'present',
        owner          => 'root',
        group          => 'root',
        mode           => '0644',
        ensure_newline => true,
        warn           => true,
      }

      concat::fragment { 'awslogs-header':
        target  => '/etc/awslogs/awslogs.conf',
        content => template('cloudwatchlogs/awslogs_header.erb'),
        order   => '00',
      }

      file { '/var/awslogs':
        ensure => 'directory',
      } ->
      file { '/var/awslogs/etc':
        ensure => 'directory',
      } ->
      file { '/var/awslogs/etc/awslogs.conf':
        ensure => 'link',
        target => '/etc/awslogs/awslogs.conf',
      }

      if ($region == undef) {
        fail("region must be defined on ${::operatingsystem}")
      } else {
        exec { 'cloudwatchlogs-install':
          path    => '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin',
          command => "python /usr/local/src/awslogs-agent-setup.py -n -r ${region} -c /etc/awslogs/awslogs.conf",
          onlyif  => '[ -e /usr/local/src/awslogs-agent-setup.py ]',
          unless  => '[ -d /var/awslogs/bin ]',
          require => [
            Concat['/etc/awslogs/awslogs.conf'],
            Exec['cloudwatchlogs-wget']
          ],
          before  => [
            Service['awslogs'],
            File['/var/awslogs/etc/awslogs.conf'],
          ]
        }
      }

      service { 'awslogs':
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        hasstatus  => true,
        subscribe  => Concat['/etc/awslogs/awslogs.conf'],
        require    => File['/var/awslogs/etc/awslogs.conf'],
      }
    }
    default: { fail("The ${module_name} module is not supported on ${::osfamily}/${::operatingsystem}.") }
  }

}
