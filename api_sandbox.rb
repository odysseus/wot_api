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

def turret_json turret
  turret_string = "
    \"#{turret['name']}\": {
        \"name\": \"#{turret['name_i18n']},
        \"tier\": #{turret['level']},
        \"viewRange\": #{turret['circular_vision_radius']},
        \"traverseSpeed\": #{turret['rotation_speed']},
        \"frontArmor\": [ #{turret['armor_forehead']}, 5 ],
        \"sideArmor\": [ #{turret['armor_board']}, 5 ],
        \"rearArmor\": [ #{turret['armor_fedd']}, 5],
        \"weight\": #{turret['weight']},
        \"stockModule\": #{turret['stock']},
        \"topModule\": #{turret['top']},
        \"experienceNeeded\": #{turret['price_xp']},
        \"cost\": #{turret['price_credit']},
        \"additionalHP\": 0,
  "
end

def gun_json gun
  gun_string = "
  \"#{gun['name']}\" : {
  \"name\": \"#{gun['name_i18n']}\",
  \"tier\": #{gun['level']},
  \"shells\": [
  [#{gun['piercing_power'][0]}, #{gun['damage'][0]}, 0, false],
  [#{gun['piercing_power'][1]}, #{gun['damage'][1]}, 0, true],
  [#{gun['piercing_power'][0]}, #{gun['damage'][0]}, 0, false]
  ],
  \"rateOfFire\": #{gun['rate']},

  }
  "
end

def tank_json tank
  # Conditionals for setting tank attributes

  # Does the tank have a turret?
  has_turret = tank['turrets'].count > 0
  # If the tank is a premium tank, price is in gold, else price in credits
  if tank['is_gift']
    tank_cost = tank['price_gold']
  else
    tank_cost = tank['price_credit']
  end
  # FIELDS THAT WILL REQUIRE REVISION:
  # experienceNeeded
  # baseHitpoints
  # gunArc
  # camoValue
  #
  # Long JSON string with the attributes
  tank_json = "
  \"#{tank['name']}\": {
    \"name\": \"#{tank['name_i18n']}\",
    \"nation\": \"#{tank['nation_i18n']}\",
    \"tier\": #{tank['level']},
    \"type\": \"#{tank['type']}\",
    \"premiumTank\": #{tank['is_gift']},
    \"turreted\": #{has_turret},
    \"experienceNeeded\": #{tank['price_xp']},
    \"cost\": #{tank_cost},
    \"baseHitpoints\": #{tank['max_health']},
    \"gunArc\": 360,
    \"speedLimit\": #{tank['speed_limit']},
    \"camoValue\": 1.00,
    \"crewLevel\": 100,
    \"topWeight\": #{tank['weight']},
    \"hull\": {
      \"frontArmor\": [ #{tank['vehicle_armor_forehead']}, 5 ],
      \"sideArmor\": [ #{tank['vehicle_armor_board']}, 5 ],
      \"rearArmor\": [ #{tank['vehicle_armor_fedd']}, 5 ]
  "
end


# This method will generate the data and call the other methods containing the 
# string conversions from the API data to the JSON representation used by the app
def generate_tank_json_for_tank tank_id
  tank = vehicle_details(tank_id)

  # Does the tank have a turret?
  has_turret = tank['turrets'].count > 0

  # First input all the basic tank information
  final_json = tank_json(tank)

  turrets_string = ""
  # Every tank has guns, so fetch those first
  # Guns
  guns = tank['guns']
  available_guns = []
  guns.each do |gun|
    available_guns.push(gun_details(gun['module_id']))
  end
  available_guns.sort! { |x,y| x['level'] <=> y['level'] }

  # First deal with Tank Destroyers, by adding the array of guns to the hull
  if tank['turrets'].count == 0

    # Now deal with turreted vehicles
  else 
    turrets = tank['turrets']
    # Turrets
    available_turrets = []
    turrets.each do |turret|
      available_turrets.push(turret_details(turret['module_id']))
    end
    # Create the stock and top values for each module
    available_turrets.each do |turret|
      turret['stock'] = false
      turret['top'] = false
    end
    # Sort by module level
    available_turrets.sort! { |x,y| x['level'] <=> y['level'] }
    # After sorting, the first item will be stock, the last item will be top
    available_turrets.first['stock'] = true
    available_turrets.last['top'] = true

    available_turrets.each do |turret|
      turret_string = turret_json(turret)
      turret_guns = available_guns.select { |x| x if x['turrets'].include?(turret['module_id']) }

      turret_string << "\n}\n}"
      turrets_string << turret_string
    end
  end
end

puts generate_tank_json_for_tank 5137
