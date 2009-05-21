$:.unshift File.join(GYMNASIUM_HOME, '..', 'lib')

require 'rudy'

dreams 'rudy myaddress' do
  dream 'no args' do
    output inline(%Q{
      Internal: #{Rudy::Utils::internal_ip_address}
      External: #{Rudy::Utils::external_ip_address}
    })
  end
  dream 'internal only' do
    output "Internal: #{Rudy::Utils::internal_ip_address}"
  end
  dream 'external only' do
    output "External: #{Rudy::Utils::external_ip_address}"
  end
  dream 'quiet' do
    output [Rudy::Utils::internal_ip_address, Rudy::Utils::external_ip_address]
  end
end

