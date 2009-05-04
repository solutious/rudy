# ----------------------------------------------------------- COMMANDS --------
# The commands block defines shell commands that can be used in routines. The
# ones defined here are added to the default list defined by Rye::Cmd (Rudy 
# executes all SSH commands via Rye). 
#
# Usage: 
#
# allow COMMAND-NAME
# allow COMMAND-NAME, '/path/2/COMMAND'
# allow COMMAND-NAME, '/path/2/COMMAND', 'default argument', 'another arg'
#
commands do
  allow :apt_get, "apt-get", :y, :q
  allow :gem_install, "/usr/bin/gem", "install", :n, '/usr/bin', :y, :V, "--no-rdoc", "--no-ri"
  allow :gem_sources, "/usr/bin/gem", "sources"
  allow :passenger_install_apache2, "passenger-install-apache2-module", '--auto'
  allow :passenger_install_nginx, "passenger-install-nginx-module", '--auto', '--autodownload'
  allow :apache2ctl
end