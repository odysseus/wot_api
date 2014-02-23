require 'json'
require './wot_api'

def parse_json_file(filename)
  text = ""
  File.open(filename, "r") do |f|
    f.each { |line| text << line }
  end
  JSON.parse(text)
end

def is_premium? price_kind
  if price_kind == "gold"
    return true
  else
    return false
  end
end

# Alternate data source doesn't include any reliable way to determine whether 
# the tank has a turret or not, so this reads the converted API JSON and makes
# a simple hash of all tanks with the name as the key and true/false as the 
# value depending on if they have a turret
def create_turreted_hash
  final = {}
  (1..10).each do |n|
    tier_text = ""
    File.open("tier#{n}.json", "r") do |file|
      file.each { |line| tier_text << line }
    end
    tier = JSON.parse(tier_text)["tier#{n}"]
    tier.each_key do |type|
      tier[type].each_key do |tank|
        final[tier[type][tank]['name']] = tier[type][tank]['turreted']
      end
    end
  end
  return final
end

# This uses the create_turreted_hash method and writes it to a file for future
# reference or reusability in other programs
def write_turret_hash
  final = create_turreted_hash.to_json
  File.open("has_turret.json", "w") do |file|
    file.write(final)
  end
end

# Does the same thing as the turreted hash creation above, for the same basic
# reasons as above
def create_weight_hash
  final = {}
  (1..10).each do |n|
    tier_text = ""
    File.open("tier#{n}.json", "r") do |file|
      file.each { |line| tier_text << line }
    end
    tier = JSON.parse(tier_text)["tier#{n}"]
    tier.each_key do |type|
      tier[type].each_key do |tank|
        final[tier[type][tank]['name']] = tier[type][tank]['stockWeight']
      end
    end
  end
  return final
end 

def write_weight_hash
  final = create_weight_hash.to_json
  File.open("stockWeight.json", "w") do |file|
    file.write(final)
  end
end

$turret_hash = create_turreted_hash
$weight_hash = create_weight_hash

def tank_hash tank
  t = {}
  nation = /\#.*\:/.match(tank['description'])[0].gsub!(/[\#\:]/, '')
  premium = is_premium?(tank['price']['kind'])
  has_turret = $turret_hash[tank['userstring']]
  t['name'] = tank['userstring']
  t['nationality'] = nation
  t['tier'] = tank['level']
  t['type'] = tank['tags']
  t['premiumTank'] = premium
  t['turreted'] = has_turret
  t['experienceNeeded'] = 0
  t['cost'] = tank['price']['value']
  t['baseHitpoints'] = tank['hull']['maxhealth']
  t['speedLimit'] = tank['speedlimits']['forward']
  t['reverseSpeed'] = tank['speedlimits']['backward']
  t['camoValue'] = 0
  t['crewLevel'] = 100
  t['stockWeight'] = $weight_hash[tank['userstring']]
  t['hull'] = {}
  t['hull']['frontArmor'] = [tank['hull']['primaryarmor'][0], 5]
  t['hull']['sideArmor'] = [tank['hull']['primaryarmor'][1], 5]
  t['hull']['rearArmor'] = [tank['hull']['primaryarmor'][2], 5]
  if has_turret
    t['turrets'] = {}
    turrets_data = tank['turrets0']
    turrets_data.each do |tkey, tdata|
      t['turrets'][tkey] = {}
      turret = t['turrets'][tkey]
      turret['name'] = tdata['userstring']
      turret['tier'] = tdata['level']
      turret['viewRange'] = tdata['circularvisionradius']
      turret['traverseSpeed'] = tdata['rotationspeed']
      turret['frontArmor'] = [tdata['primaryarmor'][0], 5]
      turret['sideArmor'] = [tdata['primaryarmor'][1], 5]
      turret['rearArmor'] = [tdata['primaryarmor'][2], 5]
      turret['weight'] = tdata['weight']
      turret['stockModule'] = false
      turret['topModule'] = false
      turret['cost'] = tdata['price']
      turret['additionalHP'] = tdata['maxhealth']
      turret['availableGuns'] = {}
      guns_data = turrets_data[tkey]['guns']
      guns_data.each do |gkey, gdata|
        t['turrets'][tkey][gkey] = {}
        gun = t['turrets'][tkey][gkey]
        gun['name'] = gdata['userstring']
        gun['tier'] = gdata['level']
        gun['rateOfFire'] = (60.0 / gdata['reloadtime'])
        gun['accuracy'] = gdata['shotdispersionradius']
        gun['aimTime'] = gdata['aimingtime']
        gun['gunDepression'] = "-#{gdata['pitchlimits'][1]}".to_i
        gun['gunElevation'] = gdata['pitchlimits'][0].to_i.abs
        gun['weight']
        gun['stockModule']
        gun['topModule']
        gun['cost']
      end
    end
  end
  return t
end

def parse_tank path
  data = parse_json_file(path)
  return tank_hash(data)
end

def convert_file filename
  tank = parse_json_file(filename)
  final = ""
  final << tank_details(tank)
end

puts parse_tank("alt_type59.json").to_json
