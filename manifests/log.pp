define cloudwatchlogs::log (
  $path            = undef,
  $streamname      = '{instance_id}',
  $datetime_format = '%b %d %H:%M:%S',
  $log_group_name  = undef,
  $multi_line_start_pattern = undef,
  $retention = '7',

){
  if $path == undef {
    $log_path = $name
  } else {
    $log_path = $path
  }
  if $log_group_name == undef {
    $real_log_group_name = $name
  } else {
    $real_log_group_name = $log_group_name
  }

  validate_absolute_path($log_path)
  validate_string($streamname)
  validate_string($datetime_format)
  validate_string($real_log_group_name)
  validate_string($multi_line_start_pattern)

  concat::fragment { "cloudwatchlogs_fragment_${name}":
    target  => '/etc/awslogs/awslogs.conf',
    content => template('cloudwatchlogs/awslogs_log.erb'),
  }~>
  exec { 'cloudwatchlogs-create':
    path    => '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin',
    command => "aws logs create-log-group --region $(grep region /etc/awslogs/awscli.conf | awk {'print \$3'}) --log-group-name ${real_log_group_name} || :",
    onlyif  => '[ -x "$(command -v aws)" ]',
    require => Service['awslogs'],
  }

  exec { 'cloudwatchlogs-retention':
    path    => '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin',
    command => "aws logs put-retention-policy --region $(grep region /etc/awslogs/awscli.conf | awk {'print \$3'}) --log-group-name ${real_log_group_name} --retention-in-days ${retention}",
    onlyif  => '[ -x "$(command -v aws)" ]',
    require => Service['awslogs'],
  }

}
