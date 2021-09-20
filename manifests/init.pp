# Install NSSM and add Windows path
class nssm {
  if !($::operatingsystem == 'windows') {
    fail('The NSSM Module is only supported for Windows Systems!')
  }

  require windows::nssm # Installs NSSM!

  windows::path { 'nssm_path_init':
    directory => 'C:\Program Files\nssm-2.24\win64'
  }
}
