@spec = Gem::Specification.new do |s|
	s.name = "rudy"
  s.rubyforge_project = 'rudy'
	s.version = "0.5.0"
	s.summary = "Not your grandparent's deployment tool."
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
  lib/annoy.rb
  lib/aws_sdb.rb
  lib/aws_sdb/error.rb
  lib/aws_sdb/service.rb
  lib/console.rb
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
  lib/rudy/aws/s3.rb
  lib/rudy/aws/simpledb.rb
  lib/rudy/cli.rb
  lib/rudy/cli/addresses.rb
  lib/rudy/cli/backups.rb
  lib/rudy/cli/config.rb
  lib/rudy/cli/deploy.rb
  lib/rudy/cli/disks.rb
  lib/rudy/cli/domains.rb
  lib/rudy/cli/groups.rb
  lib/rudy/cli/images.rb
  lib/rudy/cli/instances.rb
  lib/rudy/cli/keypairs.rb
  lib/rudy/cli/manager.rb
  lib/rudy/cli/release.rb
  lib/rudy/cli/routines.rb
  lib/rudy/cli/volumes.rb
  lib/rudy/command/addresses.rb
  lib/rudy/command/backups.rb
  lib/rudy/command/disks-old.rb
  lib/rudy/command/disks.rb
  lib/rudy/command/domains.rb
  lib/rudy/command/groups.rb
  lib/rudy/command/instances.rb
  lib/rudy/command/keypairs.rb
  lib/rudy/command/manager.rb
  lib/rudy/command/volumes.rb
  lib/rudy/config.rb
  lib/rudy/config/objects.rb
  lib/rudy/huxtable.rb
  lib/rudy/metadata/backup.rb
  lib/rudy/metadata/disk.rb
  lib/rudy/metadata/machine.rb
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
  tryouts/disks.rb
  tryouts/nested_methods.rb
  tryouts/session_tryout.rb
  )
  s.executables = %w[rudy ird]
  
  s.extra_rdoc_files = %w[README.rdoc LICENSE.txt CHANGES.txt]
  s.has_rdoc = true
  s.rdoc_options = ["--line-numbers", "--title", "Rudy: #{s.summary}", "--main", "README.rdoc"]
  s.require_paths = %w[lib]
  s.rubygems_version = '1.1.1'
  
  s.add_dependency 'echoe'
  s.add_dependency 'amazon-ec2'
  s.add_dependency 'aws-sdb'
  s.add_dependency 'net-ssh'
  s.add_dependency 'net-scp'
  s.add_dependency 'net-ssh-gateway'
  s.add_dependency 'net-ssh-multi'
  s.add_dependency 'drydock'
  s.add_dependency 'caesars'
  s.add_dependency 'rye'
  
  # http://bit.ly/2WaAgV
  #s.add_runtime_dependency('xml-simple', '>= 1.0.11')
  #s.add_dependency('xml-simple', '>= 1.0.11')
  #s.add_development_dependency('jgre-monkeyspecdoc', '>= 0.1.0')
  #s.add_development_dependency('thoughtbot-shoulda', '>= 0.1.0')
  
    
end