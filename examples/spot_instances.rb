machines do
  env :stage do                
    ami 'ami-e348af8a'               # Alestic Debian 5.0, 32-bit (US)

    pricing :spot do                 # Pricing may be :spot (with a block) or :on_demand
      bid 2.00
    end
  end  
end