
networks do
  
  office '44.44.44.44', '55.55.55.55'
  
  env :test do
    role :windows do
      addresses '11.11.11.11'
      authorize do
        port 80, :public
        port 3389, :office
        imcp '44.44.44.44'
        group 'stage-app'
      end
    end
  end
  

end 

machines do
  region :'us-east-1' do
    ami 'ami-de4daab7'               # Amazon Windows Server 2003 (US)
    size 'm1.small'
  end
  region :'eu-west-1' do
    ami 'ami-f98fa78d'               # Rudy Windows (EU)
  end
  env :test do
    role :windows do
      os :windows
    end
  end
end

routines do
  
end


