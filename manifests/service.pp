# Creates and manages a service:
define nssm::service (
  Enum['present', 'stopped', 'absent']  $ensure              = present,
  String                                $command             = undef,
  String                                $service_name        = $name,
  String                                $service_user        = 'LocalSystem',
  Optional[Sensitive[String]]           $service_pass        = undef,
  Optional[String]                      $app_parameters      = undef,
  Boolean                               $service_interactive = false,
  Optional[String]                      $log_file_path       = undef,
  Integer                               $restart_delay        = 2000
) {

  if !($::operatingsystem == 'windows') {
    fail('The NSSM Module is only supported for Windows Systems!')
  }

  require windows::nssm # Installs NSSM!

  # Set Encoding to Unicode due to ascii null character
  # http://grokbase.com/t/gg/salt-users/152vyb5vx1/weird-whitespace-problem-getting-data-out-of-cmd-run-nssm-on-windows
  $fix_encoding = '[Console]::OutputEncoding = [System.Text.Encoding]::Unicode;'

  if $ensure == present {

    $install = "install_${service_name}"
    $restart = "restart_${service_name}"

    exec { $install:
      command  => "nssm install '${service_name}' '${command}'",
      unless   => "nssm get '${service_name}' Name",
      provider => powershell,
    }

    exec { "set_${service_name}":
      require  => Exec[$install],
      command  => "nssm set '${service_name}' ObjectName '${service_user}' '${service_pass}'",
      unless   => "${fix_encoding} \$VALUE = nssm get '${service_name}' ObjectName; if (\$VALUE.Contains(\"${service_user}\")) {exit 0} else {exit 1}",
      provider => powershell,
      notify   => Exec[$restart]
    }

    exec { "set_app_parameters_${service_name}":
      require  => Exec[$install],
      command  => "nssm set '${service_name}' AppParameters '${app_parameters}'",
      unless   => "${fix_encoding} \$VALUE = nssm get '${service_name}' AppParameters; if (\$VALUE.Contains(\"${app_parameters}\")) {exit 0} else {exit 1}",
      provider => powershell,
      notify   => Exec[$restart]
    }

    exec { "set_app_exit_${service_name}":
      require  => Exec[$install],
      command  => "nssm set '${service_name}' AppExit Default Restart",
      unless   => "${fix_encoding} \$VALUE = & nssm get '${service_name}' AppExit Default; if (\$VALUE.Contains(\"Restart\")) {exit 0} else {exit 1}",
      provider => powershell,
      notify   => Exec[$restart]
    }

    exec { "set_app_throttle_${service_name}":
      require  => Exec[$install],
      command  => "nssm set '${service_name}' AppThrottle 2000",
      unless   => "${fix_encoding} \$VALUE = nssm get '${service_name}' AppThrottle; if (\$VALUE.Contains(\"2000\")) {exit 0} else {exit 1}",
      provider => powershell,
      notify   => Exec[$restart]
    }

    exec { "set_app_restart_delay_${service_name}":
      require  => Exec[$install],
      command  => "nssm set '${service_name}' AppRestartDelay ${restart_delay}",
      unless   => "${fix_encoding} \$VALUE = & nssm get '${service_name}' AppRestartDelay; if (\$VALUE.Contains(\"${restart_delay}\")) {exit 0} else {exit 1}",
      provider => powershell,
      notify   => Exec[$restart]
    }

    # If it should output a log file:
    if ($log_file_path) {
      exec { "set_app_stdout_${service_name}":
        require  => Exec[$install],
        command  => "nssm set '${service_name}' AppStdout ${log_file_path}",
        unless   => "${fix_encoding} \$VALUE = nssm get '${service_name}' AppStdout; if (\$VALUE.Contains(\"${log_file_path}\")) {exit 0} else {exit 1}",
        provider => powershell,
        notify   => Exec[$restart]
      }

      exec { "set_app_stderr_${service_name}":
        require  => Exec[$install],
        command  => "nssm set '${service_name}' AppStderr ${log_file_path}",
        unless   => "${fix_encoding} \$VALUE = nssm get '${service_name}' AppStderr; if (\$VALUE.Contains(\"${log_file_path}\")) {exit 0} else {exit 1}",
        provider => powershell,
        notify   => Exec[$restart]
      }
    }

    exec { "set_application_${service_name}":
      require  => Exec[$install],
      command  => "nssm set '${service_name}' Application ${command}",
      unless   => "${fix_encoding} \$VALUE = nssm get '${service_name}' Application; if (\$VALUE.Contains(\"${command}\")) {exit 0} else {exit 1}",
      provider => powershell,
      notify   => Exec[$restart]
    }

    if $service_interactive {
      $service_type = 'SERVICE_INTERACTIVE_PROCESS'
    } else {
      $service_type = 'SERVICE_WIN32_OWN_PROCESS'
    }

    exec { "set_type_${service_name}":
      require  => Exec[$install],
      command  => "nssm set '${service_name}' Type ${service_type}",
      unless   => "${fix_encoding} \$VALUE = nssm get '${service_name}' Type; if (\$VALUE.Contains(\"${service_type}\")) {exit 0} else {exit 1}",
      provider => powershell,
      notify   => Exec[$restart]
    }

    exec { $restart:
      require     => [
        Exec[$install],
        Exec["set_${service_name}"],
        Exec["set_app_parameters_${service_name}"],
        Exec["set_app_throttle_${service_name}"],
        Exec["set_app_restart_delay_${service_name}"],
        Exec["set_app_exit_${service_name}"],
        Exec["set_app_stdout_${service_name}"],
        Exec["set_app_stderr_${service_name}"],
        Exec["set_application_${service_name}"],
        Exec["set_type_${service_name}"]
      ],
      command     => "nssm restart ${service_name}",
      refreshonly => true,
      provider    => powershell
    }

  }

  if $ensure == absent {
    exec { "remove_${service_name}":
      command  => "nssm remove '${service_name}' confirm",
      onlyif   => "nssm get '${service_name}' Name",
      provider => powershell
    }
  }

  if $ensure == stopped {
    exec { "stop_${service_name}":
      command  => "nssm stop '${service_name}'",
      onlyif   => "nssm get '${service_name}' Name",
      provider => powershell
    }
  }

}
