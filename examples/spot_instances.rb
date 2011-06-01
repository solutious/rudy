machines do
  env :stage do
    ami 'ami-e348af8a'               # Alestic Debian 5.0, 32-bit (US)

    # Changing to spot pricing causes Rudy to aquire your instances via a "spot request"
    # to EC2, as opposed to asking EC2 to boot your instances directly (so-called "on
    # demand" instances). Consequently, the first stage of a a Rudy startup rotuine using
    # spot instances is to make a spot instance request and then wait for it to be
    # fulfilled (all instances from the request are active).
    #
    # Please see this Amazon AWS page about spot instances for more information:
    #
    # http://aws.amazon.com/ec2/spot-instances/
    #
    # Here is what a startup routine looks like using spot instances:
    #
    #   rudy git:project_name ❯ rudy startup                                                                                                                                            ✹
    #   Executing routine: startup
    #
    #   authorize port 22 access for: 70.99.250.82
    #   Waiting for 1 spot requests to be fulfilled..............................
    #   Waiting for m-us-east-1d-stage-app-01 to boot.........
    #   Waiting for public DNS on m-us-east-1d-stage-app-01 ...
    #   Waiting for port 22 on m-us-east-1d-stage-app-01 ......
    #   root@m-us-east-1d-stage-app-01# hostname m-us-east-1d-stage-app-01
    #
    #   The following machines are now available:
    #   m-us-east-1d-stage-app-01; i-d7ba09b9; ec2-50-16-129-132.compute-1.amazonaws.com
    #
    # The time you will wait for your spot request to be fulfilled can vary from as little
    # as 60 seconds, to as long as 5 minutes, depending on availability of instances in
    # your region and/or availability zone, as well as your bid price. During peak EC2
    # usage seasons (around the holidays), spot requests may take up to 24-48 hours to be
    # fulfilled.
    #
    # The Rudy startup rotuine will wait for 3 minutes before timing out and asking you if
    # you want to continue waiting.  If you do, simply type 'yes' when asked and hit
    # 'enter' to continue waiting.  If you decide you do not want to wait, type 'no' and
    # the startup routine will abort with no machines created.
    pricing :spot do                 # Pricing may be :spot (with a block) or :on_demand
      bid 2.00
    end
  end
end