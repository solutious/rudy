# Rudy Windows Machines
#
# This configuration is used to 
# test windows instance support.


defaults do
  color true
  environment :test
  role :windows
  region :'eu-west-1'
end

machines do
  region :'us-east-1' do
  end
  region :'eu-west-1' do
    ami 'ami-f98fa78d'               # Rudy Windows (EU)
  end
  env :test do
    role :windows do
      os :win32
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
