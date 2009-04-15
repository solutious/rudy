@spec = Gem::Specification.new do |s|
	s.name = "rudy"
  s.rubyforge_project = 'rudy'
	s.version = "0.6.0"
	s.summary = "Rudy: Not your grandparent's deployment tool."
	s.description = s.summary
	s.author = "Delano Mandelbaum"
	s.email = "delano@solutious.com"
	s.homepage = "http://github.com/solutious/rudy"
 
  # = MANIFEST =
  # git ls-files
  s.files = %w(
  CHANGES.txt
  LICENSE.txt
  README.rdoc
  Rakefile
  Rudyfile
  bin/ird
  bin/rudy
  bin/rudy-ec2
  lib/annoy.rb
  lib/caesars.rb
  lib/console.rb
  lib/drydock.rb
  lib/escape.rb
  lib/rudy.rb
  lib/rudy/aws.rb
  lib/rudy/aws/ec2.rb
  lib/rudy/aws/ec2/address.rb
  lib/rudy/aws/ec2/group.rb
  lib/rudy/aws/ec2/image.rb
  lib/rudy/aws/ec2/instance.rb
  lib/rudy/aws/ec2/keypair.rb
  lib/rudy/aws/ec2/snapshot.rb
  lib/rudy/aws/ec2/volume.rb
  lib/rudy/aws/ec2/zone.rb
  lib/rudy/aws/s3.rb
  lib/rudy/aws/sdb.rb
  lib/rudy/aws/sdb/error.rb
  lib/rudy/backup.rb
  lib/rudy/cli.rb
  lib/rudy/cli/aws/ec2/addresses.rb
  lib/rudy/cli/aws/ec2/candy.rb
  lib/rudy/cli/aws/ec2/groups.rb
  lib/rudy/cli/aws/ec2/images.rb
  lib/rudy/cli/aws/ec2/instances.rb
  lib/rudy/cli/aws/ec2/keypairs.rb
  lib/rudy/cli/aws/ec2/snapshots.rb
  lib/rudy/cli/aws/ec2/volumes.rb
  lib/rudy/cli/aws/ec2/zones.rb
  lib/rudy/cli/aws/sdb/domains.rb
  lib/rudy/cli/backups.rb
  lib/rudy/cli/config.rb
  lib/rudy/cli/deploy.rb
  lib/rudy/cli/disks.rb
  lib/rudy/cli/manager.rb
  lib/rudy/cli/release.rb
  lib/rudy/cli/routines.rb
  lib/rudy/command/backups.rb
  lib/rudy/command/disks.rb
  lib/rudy/command/instances.rb
  lib/rudy/command/machines.rb
  lib/rudy/command/manager.rb
  lib/rudy/config.rb
  lib/rudy/config/objects.rb
  lib/rudy/disk.rb
  lib/rudy/global.rb
  lib/rudy/huxtable.rb
  lib/rudy/machine.rb
  lib/rudy/metadata.rb
  lib/rudy/routines.rb
  lib/rudy/routines/disk_handler.rb
  lib/rudy/routines/release.rb
  lib/rudy/routines/script_runner.rb
  lib/rudy/routines/shutdown.rb
  lib/rudy/routines/startup.rb
  lib/rudy/scm/svn.rb
  lib/rudy/utils.rb
  lib/storable.rb
  lib/sysinfo.rb
  lib/tryouts.rb
  rudy.gemspec
  support/mailtest
  support/randomize-root-password
  support/rudy-ec2-startup
  support/update-ec2-ami-tools
  test/05_config/00_setup_test.rb
  test/05_config/30_machines_test.rb
  test/20_sdb/00_setup_test.rb
  test/20_sdb/10_domains_test.rb
  test/25_ec2/00_setup_test.rb
  test/25_ec2/10_keypairs_test.rb
  test/25_ec2/20_groups_test.rb
  test/25_ec2/30_addresses_test.rb
  test/25_ec2/40_volumes_test.rb
  test/25_ec2/50_snapshots_test.rb
  test/26_ec2_instances/00_setup_test.rb
  test/26_ec2_instances/10_instances_test.rb
  test/26_ec2_instances/50_images_test.rb
  test/30_sdb_metadata/00_setup_test.rb
  test/30_sdb_metadata/10_disks_test.rb
  test/30_sdb_metadata/20_backups_test.rb
  test/50_commands/00_setup_test.rb
  test/50_commands/10_keypairs_test.rb
  test/50_commands/20_groups_test.rb
  test/50_commands/40_volumes_test.rb
  test/50_commands/50_instances_test.rb
  test/coverage.txt
  test/helper.rb
  tryouts/console_tryout.rb
  tryouts/disks_tryout.rb
  tryouts/drydock_tryout.rb
  tryouts/nested_methods.rb
  tryouts/session_tryout.rb
  tryouts/usage_tryout.rb
  vendor/highline-1.5.1/CHANGELOG
  vendor/highline-1.5.1/INSTALL
  vendor/highline-1.5.1/LICENSE
  vendor/highline-1.5.1/README
  vendor/highline-1.5.1/Rakefile
  vendor/highline-1.5.1/TODO
  vendor/highline-1.5.1/examples/ansi_colors.rb
  vendor/highline-1.5.1/examples/asking_for_arrays.rb
  vendor/highline-1.5.1/examples/basic_usage.rb
  vendor/highline-1.5.1/examples/color_scheme.rb
  vendor/highline-1.5.1/examples/limit.rb
  vendor/highline-1.5.1/examples/menus.rb
  vendor/highline-1.5.1/examples/overwrite.rb
  vendor/highline-1.5.1/examples/page_and_wrap.rb
  vendor/highline-1.5.1/examples/password.rb
  vendor/highline-1.5.1/examples/trapping_eof.rb
  vendor/highline-1.5.1/examples/using_readline.rb
  vendor/highline-1.5.1/lib/highline.rb
  vendor/highline-1.5.1/lib/highline/color_scheme.rb
  vendor/highline-1.5.1/lib/highline/compatibility.rb
  vendor/highline-1.5.1/lib/highline/import.rb
  vendor/highline-1.5.1/lib/highline/menu.rb
  vendor/highline-1.5.1/lib/highline/question.rb
  vendor/highline-1.5.1/lib/highline/system_extensions.rb
  vendor/highline-1.5.1/setup.rb
  vendor/highline-1.5.1/test/tc_color_scheme.rb
  vendor/highline-1.5.1/test/tc_highline.rb
  vendor/highline-1.5.1/test/tc_import.rb
  vendor/highline-1.5.1/test/tc_menu.rb
  vendor/highline-1.5.1/test/ts_all.rb
  )
  s.executables = %w[ird rudy rudy-ec2]
  
  s.extra_rdoc_files = %w[README.rdoc Rudyfile LICENSE.txt CHANGES.txt ]
  s.has_rdoc = true
  s.rdoc_options = ["--line-numbers", "--title", s.summary, "--main", "README.rdoc"]
  s.require_paths = %w[lib]
  s.rubygems_version = '1.1.1'
  
  s.add_dependency 'echoe'
  s.add_dependency 'amazon-ec2'
  s.add_dependency 'net-ssh'
  s.add_dependency 'net-scp'
  s.add_dependency 'net-ssh-gateway'
  s.add_dependency 'net-ssh-multi'
  s.add_dependency 'rye'
  
  # http://bit.ly/2WaAgV
  #s.add_runtime_dependency('xml-simple', '>= 1.0.11')
  #s.add_dependency('xml-simple', '>= 1.0.11')
  #s.add_development_dependency('jgre-monkeyspecdoc', '>= 0.1.0')
  #s.add_development_dependency('thoughtbot-shoulda', '>= 0.1.0')
  
end

__END__

RELEASE CHECKLIST

* Disable debug mode
* Disable dev $LOAD_PATH 
* Update manifest
  * Remove tryouts
* Update executables list in gemspec
* Version number? 
  * rudy.rb
  * gemspec
* Removed "THIS VERSION IS NOT YET RELEASED"
* For rudy-ec2 commands
  * to_s
  * consistent layout
  * all actions tested
  * all options tested
  * help has command usages
  * make sure option input checks occur before argv checks
* Ruby 1.8, 1.9; JRuby 1.1, 1.2

