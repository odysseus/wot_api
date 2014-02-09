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
  raw_list = list_of_vehicles
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
        \"name\": \"#{turret['name_i18n']}\",
        \"tier\": #{turret['level']},
        \"viewRange\": #{turret['circular_vision_radius']},
        \"traverseSpeed\": #{turret['rotation_speed']},
        \"frontArmor\": [ #{turret['armor_forehead']}, 5 ],
        \"sideArmor\": [ #{turret['armor_board']}, 5 ],
        \"rearArmor\": [ #{turret['armor_fedd']}, 5],
        \"weight\": 0,
        \"stockModule\": #{turret['stock']},
        \"topModule\": #{turret['top']},
        \"experienceNeeded\": 0,
        \"cost\": #{turret['price_credit']},
        \"additionalHP\": 0,"
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
    \"accuracy\": 0,
    \"aimTime\": 0,
    \"gunDepression\": 0,
    \"gunElevation\": 0,
    \"weight\": 0,
    \"stockModule\": #{gun['stock']},
    \"topModule\": #{gun['top']},
    \"experienceNeeded\": 0,
    \"cost\": #{gun['price_credit']},
    \"autoloader\": false
  }"
end

def engine_json engine
  engine_string = %Q$
  "#{engine['name']}": {
    "name": "#{engine['name_i18n']}",
    "tier": #{engine['level']},
    "horsepower": #{engine['power']},
    "fireChance": 0.#{engine['fire_starting_chance']},
    "weight": 0,
    "stockModule": #{engine['stock']},
    "topModule": #{engine['top']},
    "experienceNeeded": 0,
    "cost": #{engine['price_credit']}
  }$
end

def radio_json radio
  radio_string = %Q$
  "#{radio['name']}": {
    "name": "#{radio['name_i18n']}",
    "tier": #{radio['level']},
    "signalRange": #{radio['distance']},
    "weight": 0,
    "stockModule": #{radio['stock']},
    "topModule": #{radio['top']},
    "experienceNeeded": 0,
    "cost": #{radio['price_credit']}
  }$
end

def suspension_json suspension
  suspension_string = %Q$
  "#{suspension['name']}": {
      "name": "#{suspension['name_i18n']}",
      "tier": #{suspension['level']},
      "loadLimit": #{suspension['max_load']},
      "traverseSpeed": #{suspension['rotation_speed']},
      "weight": 0,
      "stockModule": #{suspension['stock']},
      "topModule": #{suspension['top']},
      "experienceNeeded": 0,
      "cost": #{suspension['price_credit']}
  }$
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
    \"camoValue\": 0.00,
    \"crewLevel\": 100,
    \"topWeight\": #{tank['weight']},
    \"hull\": {
      \"frontArmor\": [ #{tank['vehicle_armor_forehead']}, 5 ],
      \"sideArmor\": [ #{tank['vehicle_armor_board']}, 5 ],
      \"rearArmor\": [ #{tank['vehicle_armor_fedd']}, 5 ]"
end


# This method will generate the data and call the other methods containing the 
# string conversions from the API data to the JSON representation used by the app
def generate_tank_json_for_tank tank_id
  tank = vehicle_details(tank_id)

  # Does the tank have a turret?
  has_turret = tank['turrets'].count > 0

  # First input all the basic tank information
  final_json = tank_json(tank)

  # Every tank has guns, so fetch those first
  # Guns
  guns = tank['guns']
  available_guns = []
  guns.each do |gun|
    available_guns.push(gun_details(gun['module_id']))
  end

  available_guns.sort! { |x,y| x['level'] <=> y['level'] }
  available_guns.each do |gun|
    gun['stock'] = false
    gun['top'] = false
  end
  available_guns.first['stock'] = true
  available_guns.last['top'] = true

  # First deal with Tank Destroyers, by adding the array of guns to the hull
  if tank['turrets'].count == 0
    guns_string = %Q$"availableGuns": {$
    available_guns.each do |gun|
      guns_string << gun_json(gun)
      guns_string << "," unless gun == available_guns.last
    end
    guns_string << "\n}"
    final_json << ",\n"
    final_json << guns_string
    final_json << "\n},"

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

    final_json << "\n},\n\"turrets\": {"
    available_turrets.each do |turret|
      turret_string = turret_json(turret)
      turret_guns = available_guns.select { |x| x if x['turrets'].include?(turret['module_id']) }
      guns_string = %Q$\n"availableGuns": {$
      turret_guns.each do |gun|
        guns_string << gun_json(gun)
        guns_string << "," unless gun == available_guns.last
      end
      guns_string << "\n}"
      turret_string << guns_string
      final_json << turret_string
      final_json << "\n}"
      final_json << "," unless turret == available_turrets.last
    end
    # End of the turrets
    final_json << "\n},"
  end

  # Begin Engines
  engines_string = %Q$\n"engines": {$
  engines = tank['engines']
  available_engines = []
  engines.each do |engine|
    available_engines.push(engine_details(engine['module_id']))
  end
  available_engines.each do |engine|
    engine['stock'] = false
    engine['top'] = false
  end
  available_engines.sort! { |x,y| x['level'] <=> y['level'] }
  available_engines.first['stock'] = true
  available_engines.last['top'] = true
  available_engines.each do |engine|
    engine_string = engine_json(engine)
    engines_string << engine_string
    engines_string << "," unless engine == available_engines.last
  end
  final_json << engines_string

  # End Engines
  final_json << %Q$\n},$

  # Begin Suspensions
  suspensions_string = %Q$\n"suspensions": {$
  suspensions = tank['chassis']
  available_suspensions = []
  suspensions.each do |s|
    available_suspensions.push(suspension_details(s['module_id']))
  end
  available_suspensions.each do |s|
    s['stock'] = false
    s['top'] = false
  end
  available_suspensions.sort! { |x,y| x['level'] <=> y['level'] }
  available_suspensions.first['stock'] = true
  available_suspensions.last['top'] = true
  available_suspensions.each do |suspension|
    suspension_string = suspension_json(suspension)
    suspensions_string << suspension_string
    suspensions_string << "," unless suspension == available_suspensions.last
  end
  final_json << suspensions_string

  # End Suspensions
  final_json << "\n},"

  # Begin Radios
  radios_string = %Q$\n"radios": {$
  radios = tank['radios']
  available_radios = []
  radios.each do |r|
    available_radios.push(radio_details(r['module_id']))
  end
  available_radios.each do |r|
    r['stock'] = false
    r['top'] = false
  end
  available_radios.sort! { |x,y| x['level'] <=> y['level'] }
  available_radios.first['stock'] = true
  available_radios.last['top'] = true
  available_radios.each do |radio|
    radio_string = radio_json(radio)
    radios_string << radio_string 
    radios_string << "," unless radio == available_radios.last
  end
  final_json << radios_string

  # End Radios
  final_json << "\n}"

  # End Tank
  final_json << "\n}"

  return final_json
end

# Type 59 id:     49
# Tiger II id:    5137
# ISU-152 id:     7425
# Hetzer id:      1809

orig_std_out = STDOUT.clone
STDOUT.reopen(File.open('output.json', 'w+'))

#puts generate_tank_json_for_tank 9249

STDOUT.reopen(orig_std_out)
