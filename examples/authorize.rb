
machines do
  env :stage do                
    user :jira                 
    ami 'ami-e348af8a'               # Alestic Debian 5.0, 32-bit (US)
  end  
end

routines do  
  setup do
    # NOTE: This fails b/c it's trying to login as jira rather than root. 
    adduser :jira
    authorize :jira
  end
end