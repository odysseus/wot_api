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

# Extract the array of modules for a given tank and module type, valid module
# types are "chassis", "engines", "guns", "radios", "turrets"
def list_available_modules tank_id, module_type
  tank = vehicle_details(tank_id)
  modules = tank[module_type]
  details = []
  modules.each do |item|
    details.push(module_details(item['module_id'], "tank#{module_type}"))
  end
  return details
end

def list_available_module_names tank_id, module_type
  modules = list_available_modules(tank_id, module_type)
  names = []
  modules.each { |item| names.push(item['name_i18n']) }
  return names
end

puts "Suspensions:"
puts list_available_module_names(5137, "chassis")
puts "Engines:"
puts list_available_module_names(5137, "engines")
puts "Guns:"
puts list_available_module_names(5137, "guns")
puts "Radios:"
puts list_available_module_names(5137, "radios")
puts "Turrets:"
puts list_available_module_names(5137, "turrets")

### Helper Methods 

# Creates an array of all tank ids, useful for iterating through every tank
def all_tanks_id_array
  id_arr = []
  tanks_hash = list_of_vehicles
  tanks_hash.each_key { |key| id_arr.push(tanks_hash[key]['id']) }
end

# Creates a dynamic tally of all tanks based on the tank-level attribute supplied
# as the argument. EG: all_tanks_count_by "type" would tally tanks by their class
# "nation_i18n" would do it by country. It works for any top level element, though
# there are only a handful of keys for which this kind of counting would be useful
def all_tanks_count_by key
  tanks_hash = list_of_vehicles
  tally = Hash.new
  tanks_hash.each_key do |tank|
    if tally[tanks_hash[tank][key]]
      tally[tanks_hash[tank][key]] += 1
    else
      tally[tanks_hash[tank][key]] = 1
    end
  end
  return tally
end

