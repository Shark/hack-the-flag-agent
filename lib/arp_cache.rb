require_relative 'exec'

class ARPCache
  Entry = Struct.new(:ip, :mac)

  def self.all
    Exec.('arp -an')
    .split("\n")
    .map do |line|
      parsed_line = /\((?<ip>\S+)\) at (?<mac>\S+)/.match(line)
      next nil unless parsed_line
      Entry.new(parsed_line[:ip], parsed_line[:mac])
    end
  end

  def self.find_entry(ip:)
    all.find {|entry| entry.ip == ip }
  end
end
