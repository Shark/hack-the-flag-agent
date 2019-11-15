begin
  require 'pry'
rescue LoadError; end

require 'dotenv/load'
require 'rack'

require_relative 'lib/arp_cache'
require_relative 'lib/updater'

update_endpoint = ENV.fetch('UPDATE_ENDPOINT')

app = Proc.new do |env|
  query = Rack::Utils.parse_nested_query(env.fetch('QUERY_STRING'))
  username = query['username']
  unless username
    next [
      '400',
      {'Content-Type' => 'text/plain'},
      ['username needs to be given in query']
    ]
  end
  ip = env.fetch('REMOTE_ADDR')
  entry = ARPCache.find_entry(ip: ip)
  if entry
    begin
      Updater.update_user_mac(
        endpoint: update_endpoint,
        username: username,
        mac: entry.mac)
    rescue => e
      puts "Error updating user: #{e}"
    end

    [
      '200',
      {'Content-Type' => 'text/plain'},
      ["MAC is #{entry.mac}"]
    ]
  else
    [
      '400',
      {'Content-Type' => 'text/plain'},
      ['MAC not found']
    ]
  end
end

run app
