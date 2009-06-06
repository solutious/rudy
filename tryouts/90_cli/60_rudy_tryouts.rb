
RUDY_HOME = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))

group "Rudy CLI"
command :rudy, File.join(RUDY_HOME, 'bin', 'rudy')

dreams File.join(GYMNASIUM_HOME, '90_cli', '60_rudy_dreams.rb')
tryout "rudy machines" do
  drill "no machines, no args", :machines
  ##drill "startup", :startup
end

tryout "rudy myaddress" do
  drill       'no args',     :myaddress
  drill 'internal only',     :myaddress, :i
  drill 'external only',     :myaddress, :e
  drill         'quiet', :q, :myaddress
end




