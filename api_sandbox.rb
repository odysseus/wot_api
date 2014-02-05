require 'net/http'
require 'json'

WOT_HOST = 'api.worldoftanks.com'
APP_ID = '19c9589415e3eefac7daf8039b2e5f1f'

def wot_api_request request_string
  Net::HTTP.get(WOT_HOST, request_string)
end

def hash_from_request_string request_string
  data = JSON.parse(wot_api_request(request_string))
  if data['status'] == 'ok'
    final = data['data']
  else
    raise "Error loading data"
  end
end

def list_of_vehicles
  request_string = "/wot/encyclopedia/tanks/?application_id=#{APP_ID}"
  tanks_hash = hash_from_request_string(request_string)
end

def vehicle_details tank_id
  request_string = 
    "/wot/encyclopedia/tankinfo/?application_id=#{APP_ID}&tank_id=#{tank_id}"
  hash_from_request_string(request_string)
end

def module_details module_id, module_type_string
  request_string = 
    "/wot/encyclopedia/#{module_type_string}/?application_id=#{APP_ID}&module_id=#{module_id}"
  hash_from_request_string(request_string)
end

def engine_details module_id
  module_details(module_id, "tankengines")
end

def turret_details module_id
  module_details(module_id, "tankturrets")
end

def radio_details module_id
  module_details(module_id, "tankradios")
end

def suspension_details module_id
  module_details(module_id, "tankchassis")
end

def gun_details module_id
  module_details(module_id, "tankguns")
end

### Helper Methods 

def all_tanks_id_array
  id_arr = []
  tanks_hash = list_of_vehicles
  tanks_hash.each_key { |key| id_arr.push(tanks_hash[key]['id']) }
end

puts vehicle_details(49)
