
RUDY_HOME = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))

group "Rudy CLI"
command :rudy, File.join(RUDY_HOME, 'bin', 'rudy')

dreams File.join(GYMNASIUM_HOME, '80_cli', '60_rudy_dreams.rb')
xtryout "rudy machines" do
  drill "no machines, no args", :machines
  ##drill "startup", :startup
end

xtryout "rudy myaddress" do
  drill       'no args',     :myaddress
  drill 'internal only',     :myaddress, :i
  drill 'external only',     :myaddress, :e
  drill         'quiet', :q, :myaddress
end


##dreams 'rudy myaddress' do
##  dream 'no args' do
##    output inline(%Q{
##  Internal: #{Rudy::Utils::internal_ip_address}
##  External: #{Rudy::Utils::external_ip_address}
##    })
##  end
##  dream 'internal only', "  Internal: #{Rudy::Utils::internal_ip_address}"
##  dream 'external only', "  External: #{Rudy::Utils::external_ip_address}"
##  dream 'quiet', [Rudy::Utils::internal_ip_address, Rudy::Utils::external_ip_address]
##end
## 
## 
##dreams 'rudy machines' do
##  dream 'no machines, no args' do
##    output inline(%Q{
##No machines running in stage-app
##Try: rudy machines --all
##    })
##  end
##end