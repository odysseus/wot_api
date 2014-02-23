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

def premium_shell? type
  if type == "gold"
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
  t['tier'] = tank['level'].to_i
  t['type'] = tank['tags']
  t['premiumTank'] = premium
  t['turreted'] = has_turret
  t['experienceNeeded'] = 0
  t['cost'] = tank['price']['value'].to_i
  t['baseHitpoints'] = tank['hull']['maxhealth'].to_i
  t['speedLimit'] = tank['speedlimits']['forward'].to_f
  t['reverseSpeed'] = tank['speedlimits']['backward'].to_f
  t['camoValue'] = 0
  t['crewLevel'] = 100
  t['stockWeight'] = $weight_hash[tank['userstring']]
  t['hull'] = {}
  t['hull']['frontArmor'] = [tank['hull']['primaryarmor'][0].to_i, 5]
  t['hull']['sideArmor'] = [tank['hull']['primaryarmor'][1].to_i, 5]
  t['hull']['rearArmor'] = [tank['hull']['primaryarmor'][2].to_i, 5]
  if has_turret
    t['turrets'] = {}
    turrets_data = tank['turrets0']
    turrets_data.each do |tkey, tdata|
      t['turrets'][tkey] = {}
      turret = t['turrets'][tkey]
      turret['name'] = tdata['userstring']
      turret['tier'] = tdata['level'].to_i
      turret['viewRange'] = tdata['circularvisionradius'].to_i
      turret['traverseSpeed'] = tdata['rotationspeed'].to_i
      turret['frontArmor'] = [tdata['primaryarmor'][0].to_i, 5]
      turret['sideArmor'] = [tdata['primaryarmor'][1].to_i, 5]
      turret['rearArmor'] = [tdata['primaryarmor'][2].to_i, 5]
      turret['weight'] = tdata['weight'].to_i
      turret['stockModule'] = false
      turret['topModule'] = false
      turret['cost'] = tdata['price'].to_i
      turret['additionalHP'] = tdata['maxhealth'].to_i
      turret['availableGuns'] = {}
      guns_data = turrets_data[tkey]['guns']
      guns_data.each do |gkey, gdata|
        t['turrets'][tkey][gkey] = {}
        gun = t['turrets'][tkey][gkey]
        gun['name'] = gdata['userstring']
        gun['tier'] = gdata['level'].to_i
        gun['rateOfFire'] = (60.0 / gdata['reloadtime'].to_f)
        gun['accuracy'] = gdata['shotdispersionradius'].to_f
        gun['aimTime'] = gdata['aimingtime'].to_f
        gun['gunDepression'] = "-#{gdata['pitchlimits'][1]}".to_i
        gun['gunElevation'] = gdata['pitchlimits'][0].to_i.abs
        gun['weight'] = gdata['weight'].to_i
        gun['stockModule'] = false
        gun['topModule'] = false
        gun['cost'] = gdata['price'].to_i
        gun['dispersion'] = {}
        gun['dispersion']['turretRotation'] = 
          gdata['shotdispersionfactors']['turretrotation'].to_f
        gun['dispersion']['afterShot'] = 
          gdata['shotdispersionfactors']['aftershot'].to_f
        gun['dispersion']['gunDamaged'] = 
          gdata['shotdispersionfactors']['whilegundamaged'].to_f
        gun['shells'] = []
        shells = gdata['shots']
        shells.each do |skey, sdata|
          arr = [
            sdata['piercingpower'][0].to_i,
            sdata['damage']['armor'].to_i,
            sdata['price']['value'].to_i,
            premium_shell?(sdata['price']['kind'])
          ]
          gun['shells'].push(arr)
        end # shell
      end # gun
    end # turret
  else
    # Deal with turretless vehicles by adding guns to the hull
    #
    # "NOT VERY DRY!" You exclaim, and yes this would be much better in different
    # methods, but for right now I'm just doing this in a purely procedural way
    # to get it into a workable format, plus dealing with the data as a blob
    # is proving the simplest way to overcome the manifold annoyances of the
    # data structuring, mine and theirs. Refactoring will come later. 
    t['hull']['availableGuns'] = {}
    guns_data = tank['turrets0']['guns']
    guns_data.each do |gkey, gdata|
      t['turrets'][tkey][gkey] = {}
      gun = t['turrets'][tkey][gkey]
      gun['name'] = gdata['userstring']
      gun['tier'] = gdata['level'].to_i
      gun['rateOfFire'] = (60.0 / gdata['reloadtime'].to_f)
      gun['accuracy'] = gdata['shotdispersionradius'].to_f
      gun['aimTime'] = gdata['aimingtime'].to_f
      gun['gunDepression'] = "-#{gdata['pitchlimits'][1]}".to_i
      gun['gunElevation'] = gdata['pitchlimits'][0].to_i.abs
      gun['weight'] = gdata['weight'].to_f
      gun['stockModule'] = false
      gun['topModule'] = false
      gun['cost'] = gdata['price'].to_i
      gun['dispersion'] = {}
      gun['dispersion']['turretRotation'] = 
        gdata['shotdispersionfactors']['turretrotation'].to_f
      gun['dispersion']['afterShot'] = 
        gdata['shotdispersionfactors']['aftershot'].to_f
      gun['dispersion']['gunDamaged'] = 
        gdata['shotdispersionfactors']['whilegundamaged'].to_f
      gun['shells'] = []
      shells = gdata['shots']
      shells.each do |skey, sdata|
        arr = [
          sdata['piercingpower'][0].to_i,
          sdata['damage']['armor'].to_i,
          sdata['price']['value'].to_i,
          premium_shell?(sdata['price']['kind'])
        ]
        gun['shells'].push(arr)
      end #shell
    end #gun
  end # has_turret
  t['engines'] = {}
  engines_data = tank['engines']
  engines_data.each do |ekey, edata|
    t['engines'][ekey] = {}
    engine = t['engines'][ekey]
    engine['name'] = edata['userstring']
    engine['tier'] = edata['level'].to_i
    engine['horsepower'] = edata['power'].to_i
    engine['firechance'] = edata['firestartingchance'].to_f
    engine['weight'] = edata['weight'].to_i
    engine['stockModule'] = false
    engine['topModule'] = false
    engine['cost'] = edata['price'].to_i
  end # engine
  t['radios'] = {}
  radios_data = tank['radios']
  radios_data.each do |rkey, rdata|
    t['radios'][rkey] = {}
    radio = t['radios'][rkey]
    radio['name'] = rdata['userstring']
    radio['tier'] = rdata['level'].to_i
    radio['signalRange'] = rdata['distance'].to_i
    radio['weight'] = rdata['weight'].to_i
    radio['stockModule'] = false
    radio['topModule'] = false
    radio['cost'] = rdata['price'].to_i
  end #radio
  t['suspensions'] = {}
  suspensions_data = tank['chassis']
  suspensions_data.each do |ckey, cdata|
    t['suspensions'][ckey] = {}
    suspension = t['suspensions'][ckey]
    suspension['name'] = cdata['userstring']
    suspension['tier'] = cdata['level'].to_i
    suspension['loadLimit'] = (cdata['maxload'].to_f / 1000.0)
    suspension['traverseSpeed'] = cdata['rotationspeed'].to_i
    suspension['weight'] = cdata['weight'].to_i
    suspension['pivot'] = cdata['rotationisaroundcenter']
    suspension['terrainResistance'] = cdata['terrainresistance']
    suspension['dispersion'] = cdata['shotdispersionfactors']['vehiclerotation'].to_f
    suspension['stockModule'] = false
    suspension['topModule'] = false
    suspension['cost'] = cdata['price'].to_i
  end # suspension
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

File.open("t44_converted.json", "w") do |file|
  file.write(parse_tank("alt_t44.json").to_json)
end
