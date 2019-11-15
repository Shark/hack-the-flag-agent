require 'http'

class Updater
  def self.update_user_mac(endpoint:, username:, mac:)
    HTTP
    .timeout(3)
    .post("#{endpoint}/#{username}", json: {mac: mac})
  end
end
