
RUDY_PATH = File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 'rudy'))

group "Rudy CLI"
command :rudy, RUDY_PATH

tryout "rudy machines" do
  drill "no machines, no args", :machines
  drill "startup", :startup
end

tryout "rudy myaddress" do
  drill       'no args',     :myaddress
  drill 'internal only',     :myaddress, :i
  drill 'external only',     :myaddress, :e
  drill         'quiet', :q, :myaddress
end
  
  