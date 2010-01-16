

module Rudy::CLI
  
  # A base for all Drydock executables (bin/rudy etc...). 
  class Base
    extend Drydock
    
    before do |obj|
      # Don't print Rudy header unless requested to
      obj.global.print_header = false  if (obj.global.verbose == 0)
      @start = Time.now
    end

    after do |obj|  
      if obj.global.verbose > 0
        puts
        @elapsed = Time.now - @start
        puts "Elapsed: %.2f seconds" % @elapsed.to_f if @elapsed > 0.1
      end
    end
    
    # These globals are used by all bin/ executables
    global :A, :accesskey, String, "AWS Access Key"
    global :S, :secretkey, String, "AWS Secret Access Key"
    global :R, :region, String, "Amazon service region (e.g. #{Rudy::DEFAULT_REGION})"
    global :z, :zone, String, "Amazon Availability zone (e.g. #{Rudy::DEFAULT_ZONE})"
    global :u, :user, String, "Provide a username (ie: #{Rudy.sysinfo.user})"
    global :l, :localhost, String, "Provide a localhost (e.g. #{Rudy.sysinfo.hostname})"
    global :i, :identity, String, "Path to SSH identity (private key) for RSA or DSA authentication"
    global :k, :pkey, String, "AWS Private Encryption Key (pk-****.pem)"
    global :c, :cert, String, "AWS Private Certificate (cert-****.pem)"
    global :f, :format, String, "Output format"
    global :n, :nocolor, "Disable output colors"
    global :Y, :auto, "Skip interactive confirmation"
    global :q, :quiet, "Run with less output"
    global :O, :offline, "Be cool about the internet being down"
    global :C, :config, String, "Specify another configuration file to read (e.g. #{Rudy::CONFIG_FILE})" do |val|
      @configs ||= []
      @configs << val
    end
    global :v, :verbose, "Increase verbosity of output (e.g. -v or -vv or -vvv)" do
      @verbose ||= 0
      @verbose += 1
    end
    global :V, :version, "Display version number" do
      puts "Rudy version: #{Rudy::VERSION}"
      exit 0
    end
    global :D, :debug, "Enable debug mode" do
      Drydock.debug true
      Rudy.enable_debug
    end
    
  end

end
