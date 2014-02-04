require 'net/http'
require 'json'

WOT_HOST = 'api.worldoftanks.com'
APP_ID = '19c9589415e3eefac7daf8039b2e5f1f'

def tank_list
  request_string = "/wot/encyclopedia/tanks/?application_id=#{APP_ID}"
  Net::HTTP.get(WOT_HOST, request_string)
end

def tank_json
  tank_string = tank_list
  tank_hash = JSON.parse(tank_list)
  if tank_hash['status'] == 'ok'
    tank_json = tank_hash['data']
  else
    puts "Error retrieving data"
  end
end

def tank_info tank_id
  Net::HTTP.get(WOT_HOST, 
                "/wot/encyclopedia/tankinfo/?application_id=#{APP_ID}&tank_id=#{tank_id}")
end

puts "Total number of tanks: #{tank_json.count}"

# Make an array of all the tank id's
id_arr = []
tank_json.each_key { |key| id_arr.push(tank_json[key]['id']) }

# Counting the tanks by nationality 
nationality_count = Hash.new()
tank_json.each_key do |key|
  nationality = tank_json[key]['nation_i18n']
  if not nationality_count[nationality]
    nationality_count[nationality] = 1
  else
    nationality_count[nationality] += 1
  end
end

nationality_count.each { |key, value| puts "#{key}: #{value}" }

puts tank_info(49)
