require 'json'
require './wot_api'

def parse_json_file(filename)
  text = ""
  File.open(filename, "r") do |f|
    f.each { |line| text << line }
  end
  JSON.parse(text)
end

# Alternate data source doesn't include any reliable way to determine whether 
# the tank has a turret or not, so this reads the converted API JSON and makes
# a simple hash of all tanks with the name as the key and true/false as the 
# value depending on if they have a turret
def create_turreted_hash
  final = {}
  (1..10).each do |n|
    tier_text = ""
    File.open("../tier_files/tier#{n}.json", "r") do |file|
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
  File.open("../ref/has_turret.json", "w") do |file|
    file.write(final)
  end
end

# Does the same thing as the turreted hash creation above, for the same basic
# reasons as above
def create_weight_hash
  final = {}
  (1..10).each do |n|
    tier_text = ""
    File.open("../tier_files/tier#{n}.json", "r") do |file|
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
  File.open("../ref/stockWeight.json", "w") do |file|
    file.write(final)
  end
end
