define profile::application::builder::jobs(
    $image_name,
    $url,
    $latest,
    $checksum_file,
    $checksum,
    $min_ram,
    $min_disk,
    $username,
    $ensure        = present,
    $flavor        = $profile::application::builder::flavor,
    $network       = $profile::application::builder::network,
    $az            = $profile::application::builder::real_az,
    $user          = $profile::application::builder::user,
    $group         = $profile::application::builder::group,
    $template_dir  = $profile::application::builder::template_dir,
    $download_dir  = $profile::application::builder::download_dir,
    $rc_file       = $profile::application::builder::rc_file
) {

  $hour = fqdn_rand(23, $name)

  file { '/var/log/imagebuilder':
    ensure => directory,
    user   => $user,
    group  => $group,
    mode   => '0755'
  }

  file { "/home/${user}/build_scripts/${name}":
    ensure  => $ensure,
    content => template("${module_name}/application/builder/build_script.erb"),
    owner   => $user,
    group   => $group,
    mode    => '0755',
    require => File["/home/${user}/build_scripts"]
  } ->
  cron { $name:
    ensure  => $ensure,
    # Write to imagebuilder report
    command => "/home/${user}/build_scripts/${name} || jq -n '{\"result\": \"failed\"}' >> /var/log/imagebuilder/${name}-report.jsonl",
    user    => $user,
    weekday => 'Wednesday',
    hour    => $hour,
    minute  => 0
  }

}
