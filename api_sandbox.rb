require 'net/http'
require 'json'
require './wot_api'

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
    \"name\": \"#{gun['name_i18n'] || 'missing'}\",
    \"tier\": #{gun['level'] || 0},
    \"shells\": [
    [#{gun['piercing_power'][0] || 0}, #{gun['damage'][0] || 0}, 0, false],
    [#{gun['piercing_power'][1] || 0}, #{gun['damage'][1] || 0}, 0, true],
    [#{gun['piercing_power'][2] || 0}, #{gun['damage'][2] || 0}, 0, false]
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
  if tank['premium']
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
    \"nation\": \"#{tank['nation']}\",
    \"tier\": #{tank['level']},
    \"type\": \"#{tank['type']}\",
    \"premiumTank\": #{tank['premium']},
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
  list = $list_of_vehicles
  tank['premium'] = list["#{tank_id}"]["is_premium"]

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
    view_range_string = %Q$,\n"viewRange": #{tank['circular_vision_radius']}$
    final_json << view_range_string
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
        guns_string << "," unless gun == turret_guns.last
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

def generate_json_for_tier num
  tier = $sorted_vehicle_dict["tier#{num}"]
  tier_string = %Q$"tier#{num}": {$
  n = 0
  tier.each_key do |type|
    type_string = %Q$\n"#{type}": {$
    tier[type].each do |tank|
      begin
        tank_json = generate_tank_json_for_tank(tank)
        type_string << tank_json
      rescue 
        File.open('failedtanks.txt', 'w') do |file|
          file.write("#{tank['tank_id']}")
        end
      end
      type_string << "," unless tank == tier[type].last
    end
    type_string << "\n}"
    n += 1
    type_string << "," unless n == tier.count
    tier_string << type_string
  end
  tier_string << "\n}"
  tier_string.gsub!( /Fu\.Spr\.Ger\. "a"/, "Fu.Spr.Ger. \\\"a\\\"")
  tier_string.gsub!( /Fu\.Spr\.Ger\. "f"/, "Fu.Spr.Ger. \\\"f\\\"")
  tier_string.gsub!( /Fu\.Spr\.Ger\. "d"/, "Fu.Spr.Ger. \\\"d\\\"")
  return tier_string
end

def write_json_for_tier num
  File.open("tier#{num}.json", 'w') do |file|
    file.write("{\n")
    file.write(generate_json_for_tier(num))
    file.write("\n}")
  end
  puts "Finished writing tier #{num}: #{Time.now}"
end

def generate_all
  (1..10).each do |n|
    write_json_for_tier(n)
  end
end

def create_name_checklist
  final = {}
  $sorted_vehicle_dict.each_key do |tier|
    final[tier] = {}
    $sorted_vehicle_dict[tier].each_key do |type|
      final[tier][type] = []
      $sorted_vehicle_dict[tier][type].each do |tankid|
        tank = $list_of_vehicles[tankid.to_s]
        tankstring = "#{tank['name_i18n']} - #{tank['nation_i18n']}"
        final[tier][type].push(tankstring)
      end # tank
    end # type
  end # tier
  return final
end

# Type 59 id:     49
# Tiger II id:    5137
# ISU-152 id:     7425
# Hetzer id:      1809

$list_of_vehicles = list_of_vehicles
$sorted_vehicle_dict = sorted_vehicle_dict
