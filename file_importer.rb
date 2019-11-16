begin
  require 'pry'
rescue LoadError; end

require 'dotenv/load'
require 'json'
require 'optparse'
require 'influxdb'
require 'http'

Movement = Struct.new(:timestamp, :mac, :x, :y, :z, :ssid, :event_id)
influxdb = InfluxDB::Client.new(url: ENV.fetch('INFLUXDB_URL'), open_timeout: 3)
processed_event_ids = {}

def fetch_live_feed
  movements = []
  resp = HTTP.timeout(1).get(ENV.fetch('LIVE_FEED_URL'))
  # body = JSON.parse(resp.body)
  body = parse_live_feed(resp.body)
  body.each do |el|
    el['notifications'].each do |m|
      unless m['notificationType'] == 'locationupdate'
        puts "skipping because notificationType #{m['notificationType']}"
        next
      end

      unless m['hierarchyDetails']['building']['name'] == 'Väre'
        puts "skipping because building #{m['hierarchyDetails']['building']['name']}"
        next
      end

      movements << Movement.new(
        Time.at(Integer(m['timestamp']) / 1000),
        m['deviceId'],
        Integer(m['locationCoordinate']['x']),
        Integer(m['locationCoordinate']['y']),
        Integer(m['hierarchyDetails']['floor']['name']),
        m['ssid'],
        m['eventId']
      )
    end
  end
  movements
rescue HTTP::ConnectionError => e
  puts "Error fetch live feed: #{e}"
  []
end

def parse_live_feed(body)
  str = "[#{body.to_s.delete_suffix(",\n")}]"
  str.gsub!('} {', '},{')
  str.gsub!('}{', '},{')
  JSON.parse(str)
rescue JSON::ParserError => e
  puts "Error fetch live feed: #{e}"
  []
end

loop do
  points = fetch_live_feed
           .select {|m| processed_event_ids[m.event_id] == nil }
           .map do |m|
            floor_mapping = {
              0 => 'zero',
              1 => 'one',
              2 => 'two',
              3 => 'three',
            }
            puts m
             processed_event_ids[m.event_id] = true
             {
              series: 'movement',
              values: {x: m.x, y: m.y, z: m.z},
              tags: {mac: m.mac, ssid: m.ssid, floor: floor_mapping.fetch(m.z, 'NOT APPLICABLE')},
              timestamp: m.timestamp.to_i,
            }
           end
  influxdb.write_points(points)
  puts "Imported #{points.count} movements"
  sleep 1
end
