require 'pry'
require 'dotenv/load'
require 'json'
require 'influxdb'
require 'http'
require 'pp'

db = InfluxDB::Client.new(url: ENV.fetch('INFLUXDB_URL'), open_timeout: 3)
mapping = {}

grouped = db.query 'select * from movement where time > now()-5m group by ssid'
grouped.select! {|entry| ['aalto open', 'Junction', 'eduroam'].include? entry['tags']['ssid']}

mapping = {}
grouped.each { |ssid| ssid['values'].each {|entry| mapping[entry['mac']] = []}}
grouped.each do |ssid|
  ssid['values'].each do |entry|
    mapping[entry['mac']] = mapping[entry['mac']] | [ssid['tags']['ssid']]
  end
end

mapping.select! {|_mac, ssids| ssids.count > 1}
mapping = mapping.map do |mac, ssids|
  group_first = grouped.find {|group| group['tags']['ssid'] == ssids[0]}
  group_second = grouped.find {|group| group['tags']['ssid'] == ssids[1]}
  entry_first = group_first['values'].reverse_each.find {|entry| entry['mac'] == mac}
  entry_second = group_second['values'].reverse_each.find {|entry| entry['mac'] == mac}
  time_first = Time.parse(entry_first['time'])
  time_second = Time.parse(entry_second['time'])
  if time_first < time_second
    info = {from: ssids[0], to: ssids[1], floor: entry_second['floor'], last_seen: time_second}
  else # => time_first >= time_second
    info = {from: ssids[1], to: ssids[0], floor: entry_first['floor'], last_seen: time_first}
  end
  [mac, info]
end.to_h

pp mapping
