
commands do
  allow :apt_get, "apt-get", :y, :q
  allow :gem_install, "/usr/bin/gem", "install", :n, '/usr/local/bin', :y, :V, "--no-rdoc", "--no-ri"
  allow :gem_sources, "/usr/bin/gem", "sources"
  allow :passenger_install, "passenger-install-apache2-module", :a
  allow :apache2ctl
end