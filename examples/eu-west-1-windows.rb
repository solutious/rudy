


machines do
  
  env :dev do
    role :windows do
      ami 'ami-f98fa78d'
      hostname 'should-not-set'
      os :win32
    end
  end
  
end

defaults do
  zone :'eu-west-1b'
  environment :dev
  role :windows
  color true                         # Terminal colors? true/false
  user :root                   # The default remote user
  #localhost 'hostname'              # A local hostname instead of localhost
  #auto true                         # Skip interactive confirmation?
  #keydir 'path/2/keys/'             # The path to store SSH keys
end
