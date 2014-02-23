# Script for methods that should probably be deleted, but keeping them around
# for a day or so just in case

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
  t['name'] = tank['userstring']
  t['nationality'] = nation
  t['tier'] = tank['level']
  t['type'] = tank['tags']
  t['premiumTank'] = premium
  t['turreted'] = $turret_hash[tank['userstring']]
  t['experienceNeeded'] = 0
  t['cost'] = tank['price']['value']
  t['baseHitpoints'] = tank['hull']['maxhealth']
  t['speedLimit'] = tank['speedlimits']['forward']
  t['reverseSpeed'] = tank['speedlimits']['reverse']
  t['camoValue'] = 0
  t['crewLevel'] = 100
  t['stockWeight'] = $weight_hash[tank['userstring']]
  t['hull'] = {}
  t['hull']['frontArmor'] = [tank['hull']['primaryarmor'][0], 5]
  t['hull']['sideArmor'] = [tank['hull']['primaryarmor'][1], 5]
  t['hull']['rearArmor'] = [tank['hull']['primaryarmor'][2], 5]
end

def tank_details tank
  nation = /\#.*\:/.match(tank['description'])[0].gsub!(/[\#\:]/, '')
  premium = is_premium?(tank['price']['kind'])
  tank_details = %Q$
  "#{tank['description']}": {
    "name": "#{tank['userstring']}",
    "nationality": "#{nation}",
    "tier": #{tank['level']},
    "type": "#{tank['tags']}",
    "premiumTank": #{premium},
    "turreted": #{$turret_hash[tank['userstring']]},
    "experienceNeeded": 0,
    "cost": #{tank['price']['value']},
    "baseHitpoints": #{tank['hull']['maxhealth']},
    "gunArc": 0,
    "speedLimit": #{tank['speedlimits']['forward']},
    "reverseSpeed": #{tank['speedlimits']['reverse']},
    "camoValue": 0,
    "crewLevel": 100,
    "stockWeight": #{$weight_hash[tank['userstring']].to_f},
    "hull": {
        "frontArmor": [
                       #{tank['hull']['primaryarmor'][0]},
                       5
                       ],
        "sideArmor": [
                      #{tank['hull']['primaryarmor'][1]},
                      5
                      ],
        "rearArmor": [
                      #{tank['hull']['primaryarmor'][2]},
                      5
                      ]
    },
  $
end

def turret_details turret
  turret_details = %Q$
  "#{turret['userstring']}": {
            "name": #{turret['userstring']},
            "tier": #{turret['level']},
            "viewRange": #{turret['circularvisionradius']},
            "traverseSpeed": #{turret['rotationspeed']},
            "frontArmor": [
                           #{turret['primaryarmor'][0]},
                           5
                           ],
            "sideArmor": [
                          #{turret['primaryarmor'][1]},
                          5
                          ],
            "rearArmor": [
                          #{turret['primaryarmor'][2]},
                          5
                          ],
            "weight": #{turret['weight']},
            "stockModule": false,
            "topModule": false,
            "experienceNeeded": 0,
            "cost": #{turret['price']},
            "additionalHP": #{turret['maxhealth']},
            "availableGuns": {
            $
  return turret_details
end

def gun_details gun
  gun_details = %Q$
                "#{gun['userstring']}": {
                    "name": "#{gun['userstring']}",
                    "tier": #{gun['level']},
                    "shells": [
                               [
                                181,
                                250,
                                252,
                                false
                                ],
                               [
                                241,
                                250,
                                11,
                                true
                                ],
                               [
                                50,
                                330,
                                252,
                                false
                                ]
                               ],
                    "rateOfFire": 6.9,
                    "accuracy": 0.39,
                    "aimTime": 2.9,
                    "gunDepression": -7,
                    "gunElevation": 20,
                    "weight": 2257,
                    "stockModule": true,
                    "topModule": true,
                    "experienceNeeded": 0,
                    "cost": 0
                }
                $
  return gun_details
end


def convert_file filename
  tank = parse_json_file(filename)
  final = ""
  final << tank_details(tank)
end

puts convert_file("alt_type59.json")

