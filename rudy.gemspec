@spec = Gem::Specification.new do |s|
	s.name = "rudy"
	s.version = "0.4.0"
	s.summary = "Your friend in staging and deploying with EC2."
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
  bin/rudy
  bin/rudy-ec2
  lib/aws_sdb.rb
  lib/aws_sdb/error.rb
  lib/aws_sdb/service.rb
  lib/console.rb
  lib/rudy.rb
  lib/rudy/aws.rb
  lib/rudy/aws/ec2.rb
  lib/rudy/aws/s3.rb
  lib/rudy/aws/simpledb.rb
  lib/rudy/command/addresses.rb
  lib/rudy/command/backups.rb
  lib/rudy/command/base.rb
  lib/rudy/command/config.rb
  lib/rudy/command/deploy.rb
  lib/rudy/command/disks.rb
  lib/rudy/command/environment.rb
  lib/rudy/command/groups.rb
  lib/rudy/command/images.rb
  lib/rudy/command/instances.rb
  lib/rudy/command/machines.rb
  lib/rudy/command/metadata.rb
  lib/rudy/command/release.rb
  lib/rudy/command/volumes.rb
  lib/rudy/config.rb
  lib/rudy/metadata.rb
  lib/rudy/metadata/backup.rb
  lib/rudy/metadata/disk.rb
  lib/rudy/scm/svn.rb
  lib/rudy/utils.rb
  lib/storable.rb
  lib/tryouts.rb
  rudy.gemspec
  support/mailtest
  support/rudy-ec2-startup
  tryouts/console_tryout.rb
  )
  s.executables = %w[rudy rudy-ec2]
  
  s.extra_rdoc_files = %w[README.rdoc LICENSE.txt]
  s.has_rdoc = true
  s.rdoc_options = ["--line-numbers", "--title", "Rudy: #{s.summary}", "--main", "README.rdoc"]
  s.require_paths = %w[lib]
  s.rubygems_version = '1.1.1'

  
  s.add_dependency 'drydock'
  s.add_dependency 'caesars'
  s.add_dependency 'echoe'
  s.add_dependency 'amazon-ec2'
  s.add_dependency 'aws-sdb'
  s.add_dependency 'net-ssh'
  s.add_dependency 'net-scp'
  s.add_dependency 'net-ssh-gateway'
  s.add_dependency 'net-ssh-multi'
  s.add_dependency 'highline'
  
    
  s.rubyforge_project = 'rudy'
end