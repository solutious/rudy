# Rudy Solaris Machines
#
# This configuration is used to 
# test solaris instance support.


defaults do
  color true
  environment :test
  role :solaris
end

machines do
  region :'us-east-1' do
    ami 'ami-8f30d1e6'               # OpenSolaris 2009.06 32-bit  (US)
  end
  region :'eu-west-1' do
    ami 'ami-2381a957'               # OpenSolaris 2009.06 32-bit  (EU)
  end
  env :test do
    role :solaris do
      user :root
    end
  end
end

routines do
  
  uname do
    remote :root do
      uname :a
    end
  end
  
end
