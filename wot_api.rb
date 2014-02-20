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

def sorted_vehicle_dict
  # Create the structure for the sorted dictionary
  sorted_dict = {}
  (1..10).each { |x| sorted_dict["tier#{x}"] = {} }
  # Pull the data
  raw_list = $list_of_vehicles
  raw_list.each_key do |key|
    if not sorted_dict["tier#{raw_list[key]['level']}"][raw_list[key]['type']]
      sorted_dict["tier#{raw_list[key]['level']}"][raw_list[key]['type']] = [raw_list[key]['tank_id']]
    else
      sorted_dict["tier#{raw_list[key]['level']}"][raw_list[key]['type']].push(raw_list[key]['tank_id'])
    end
  end
  return sorted_dict
end

# The first two levels of the hash returned by the API are stripped, retaining
# only the hash containing the tank data itself. Note that this includes 
# removing the tank id number
def vehicle_details tank_id
  request_string = 
    "/wot/encyclopedia/tankinfo/?application_id=#{APP_ID}&tank_id=#{tank_id}"
  data = hash_from_request_string(request_string)
  return data["#{tank_id}"]
end

# Like the vehicle_details method, the first two levels of the API hash are 
# stripped, retaining only the information about the module, this includes 
# removing the module_id. If the module id is needed, remove the last line.
def module_details module_id, module_type_string
  request_string = 
    "/wot/encyclopedia/#{module_type_string}/?application_id=#{APP_ID}&module_id=#{module_id}"
  data = hash_from_request_string(request_string)
  return data["#{module_id}"]
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
