

machines do
  
end


routines do
  often do 
    remote :root do
      uname :a
    end
  end
  newuser do
    adduser :randy
  end
  
end


defaults do
  zone :'us-east-1d'
  environment :stage
  role :app
  color true                         # Terminal colors? true/false
  user :root                   # The default remote user
  #localhost 'hostname'              # A local hostname instead of localhost
  #auto true                         # Skip interactive confirmation?
  #keydir 'path/2/keys/'             # The path to store SSH keys
end
