@spec = Gem::Specification.new do |s|
	s.name = "rudy"
  s.rubyforge_project = 'rudy'
	s.version = "0.8.5"
	s.summary = "Rudy: Not your grandparents' EC2 deployment tool."
	s.description = s.summary
	s.author = "Delano Mandelbaum"
	s.email = "delano@solutious.com"
	s.homepage = "http://github.com/solutious/rudy"
  
  s.extra_rdoc_files = %w[README.rdoc Rudyfile LICENSE.txt CHANGES.txt]
  s.has_rdoc = true
  s.rdoc_options = ["--line-numbers", "--title", s.summary, "--main", "README.rdoc"]
  s.require_paths = %w[lib]
  s.rubygems_version = '1.1.1'
  
  s.add_dependency 'rye',        '>= 0.8.1'
  s.add_dependency 'annoy',      '>= 0.5.3'
  s.add_dependency 'drydock',    '>= 0.6.5'
  s.add_dependency 'caesars',    '>= 0.7.2'
  s.add_dependency 'sysinfo',    '>= 0.5.1'
  s.add_dependency 'storable',   '>= 0.5.3'
  
  s.add_dependency 'aws-s3',     '>= 0.6.1'  # Ruby 1.9.1 compatability
  s.add_dependency 'highline',   '>= 1.5.1'  # Ruby 1.9.1 compatability
  s.add_dependency 'amazon-ec2', '>= 0.3.8'  # Region fix

  # One of the other dependencies needs these gems 
  # but doesn't seem to specify them. Why I outta!
  s.add_dependency 'tenderlove-frex'
  s.add_dependency 'archive-tar-minitar'
  s.add_dependency 'nokogiri'
  s.add_dependency 'echoe'
  s.add_dependency 'racc'
  s.add_dependency 'hoe'
  
  # libxml2 libxml2-dev libxslt-dev
  
  # http://bit.ly/2WaAgV
  #s.add_runtime_dependency('xml-simple', '>= 1.0.11')
  #s.add_dependency('xml-simple', '>= 1.0.11')
  #s.add_development_dependency('jgre-monkeyspecdoc', '>= 0.1.0')
  #s.add_development_dependency('thoughtbot-shoulda', '>= 0.1.0')
  
  s.executables = %w[rudy rudy-ec2 rudy-sdb rudy-s3]
  
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
  bin/rudy-s3
  bin/rudy-sdb
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
  lib/rudy/cli/aws/s3/buckets.rb
  lib/rudy/cli/aws/s3/store.rb
  lib/rudy/cli/aws/sdb/domains.rb
  lib/rudy/cli/candy.rb
  lib/rudy/cli/config.rb
  lib/rudy/cli/disks.rb
  lib/rudy/cli/machines.rb
  lib/rudy/cli/metadata.rb
  lib/rudy/cli/routines.rb
  lib/rudy/config.rb
  lib/rudy/config/objects.rb
  lib/rudy/global.rb
  lib/rudy/guidelines.rb
  lib/rudy/huxtable.rb
  lib/rudy/machines.rb
  lib/rudy/metadata.rb
  lib/rudy/metadata/backup.rb
  lib/rudy/metadata/backups.rb
  lib/rudy/metadata/debug.rb
  lib/rudy/metadata/disk.rb
  lib/rudy/metadata/disks.rb
  lib/rudy/metadata/objectbase.rb
  lib/rudy/mixins.rb
  lib/rudy/mixins/hash.rb
  lib/rudy/mixins/symbol.rb
  lib/rudy/routines.rb
  lib/rudy/routines/base.rb
  lib/rudy/routines/helperbase.rb
  lib/rudy/routines/helpers/dependshelper.rb
  lib/rudy/routines/helpers/diskhelper.rb
  lib/rudy/routines/helpers/hosthelper.rb
  lib/rudy/routines/helpers/scripthelper.rb
  lib/rudy/routines/helpers/userhelper.rb
  lib/rudy/routines/passthrough.rb
  lib/rudy/routines/reboot.rb
  lib/rudy/routines/shutdown.rb
  lib/rudy/routines/startup.rb
  lib/rudy/utils.rb
  rudy.gemspec
  support/mailtest
  support/randomize-root-password
  support/rudy-ec2-startup
  support/update-ec2-ami-tools
  tryouts/01_mixins/01_hash_tryouts.rb
  tryouts/10_require_time/10_rudy_tryouts.rb
  tryouts/10_require_time/15_global_tryouts.rb
  tryouts/12_config/10_load_config_tryouts.rb
  tryouts/12_config/20_defaults_tryouts.rb
  tryouts/12_config/30_accounts_tryouts.rb
  tryouts/12_config/40_machines_tryouts.rb
  tryouts/12_config/50_commands_tryouts.rb
  tryouts/12_config/60_routines_tryouts.rb
  tryouts/15_huxtable/10_huxtable_tryouts.rb
  tryouts/20_simpledb/10_domains_tryouts.rb
  tryouts/20_simpledb/20_objects_tryouts.rb
  tryouts/25_ec2/00_setup_test.rb
  tryouts/25_ec2/10_keypairs_test.rb
  tryouts/25_ec2/10_keypairs_tryouts.rb
  tryouts/25_ec2/20_groups_test.rb
  tryouts/25_ec2/30_addresses_test.rb
  tryouts/25_ec2/40_volumes_test.rb
  tryouts/25_ec2/50_snapshots_test.rb
  tryouts/26_ec2_instances/00_setup_test.rb
  tryouts/26_ec2_instances/10_instances_test.rb
  tryouts/26_ec2_instances/50_images_test.rb
  tryouts/30_metadata/50_disk_old_tryouts.rb
  tryouts/30_metadata/50_disk_tryouts.rb
  tryouts/80_cli/10_rudyec2_dreams.rb
  tryouts/80_cli/10_rudyec2_tryouts.rb
  tryouts/80_cli/60_rudy_dreams.rb
  tryouts/80_cli/60_rudy_tryouts.rb
  tryouts/failer
  tryouts/misc/console_tryout.rb
  tryouts/misc/disks_tryout.rb
  tryouts/misc/drydock_tryout.rb
  tryouts/misc/nested_methods.rb
  tryouts/misc/session_tryout.rb
  tryouts/misc/tryouts.rb
  tryouts/misc/usage_tryout.rb
  )

  
end
