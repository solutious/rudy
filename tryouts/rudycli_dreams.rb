$:.unshift File.join(GYMNASIUM_HOME, '..', 'lib')

require 'rudy'

dreams 'rudy myaddress' do
  dream 'no args' do
    output inline(%Q{
      Internal: #{Rudy::Utils::internal_ip_address}
      External: #{Rudy::Utils::external_ip_address}
    })
  end
  dream 'internal only', "Internal: #{Rudy::Utils::internal_ip_address}"
  dream 'external only', "External: #{Rudy::Utils::external_ip_address}"
  dream 'quiet', [Rudy::Utils::internal_ip_address, Rudy::Utils::external_ip_address]
end


dreams 'rudy machines' do
  dream 'no machines, no args' do
    output inline(%Q{
      No machines running in stage-app
      Try: rudy machines --all
    })
  end
end
