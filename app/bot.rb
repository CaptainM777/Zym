# Required gems for the bot initialization
require 'discordrb'
require 'sequel'
require 'json'
require 'botoperations'

# The main bot; all individual crystals will be submodules of this, giving them
# access to the bot object as a constant, Bot::BOT
module Bot
  puts '==GEODE: A Clunky Modular Ruby Bot Framework With A Database=='

  # Sets path to the data folder as environment variable
  ENV['DATA_PATH'] = File.expand_path('data')
  config_folder_path = File.expand_path("#{ENV['DATA_PATH']}/config_files")

  # Master config file, to eventually be parsed by the CommandBot constructor
  config = JSON.parse(File.read("#{config_folder_path}/config.json"), symbolize_names: true)

  # Converts the values for 'log_mode' and 'type' to symbols so that they can be properly parsed by the CommandBot constructor
  config[:log_mode] = config[:log_mode].to_sym
  config[:type] = config[:type].to_sym

  puts "Loading server settings..."

  bot_tokens = JSON.parse(File.read("#{config_folder_path}/bot_tokens.json"))
  # Sets the server settings, token, and prefix based on what bot I want to use
  if config[:bot].downcase == "proto-zym" || config[:bot].downcase == "zym"
    ENV['SERVER_SETTINGS'] = File.read("#{config_folder_path}/dragon_prince.json")
    puts "+ Loaded settings for the Dragon Prince server."

    config[:token] = bot_tokens[(config[:bot].downcase == "proto-zym") ? "proto-zym": "zym"]
    config[:prefix] = (config[:bot].downcase == "proto-zym") ? "=" : "-"
  elsif config[:bot].downcase == "bait"
    ENV['SERVER_SETTINGS'] = File.read("#{config_folder_path}/personal_server.json")
    puts "+ Loaded settings for your personal server."

    config[:token] = bot_tokens["bait"]
    config[:prefix] = "="
  else
    puts "Unknown bot detected. Exiting."
    exit(false)
  end

  puts "Done."

  # Deletes the 'bot' and 'game' keys so it doesn't get parsed by the CommandBot
  config.delete(:bot)
  game = config[:game]
  config.delete(:game)

  puts 'Initializing the bot object...'

  # Creates the bot object using the config attributes; this is a constant
  # in order to make it accessible by crystals
  BOT = Discordrb::Commands::CommandBot.new(config.to_h)

  # Sets bot's playing game
  BOT.ready { BOT.game = game }

  puts 'Done.'

  puts 'Loading application data (database, models, etc.)...'

  # Database constant
  DB = Sequel.sqlite(ENV['DB_PATH'])

  # Load model classes and print to console
  Models = Module.new
  Dir['app/models/**/*.rb'].each do |path|
    load path
    if (filename = File.basename(path, '.*')).end_with?('_singleton')
      puts "+ Loaded singleton model class #{filename[0..-11].camelize}"
    else
      puts "+ Loaded model class #{filename.camelize}"
    end
  end

  puts 'Done.'

  puts 'Loading additional scripts in lib directory...'

  # Loads the constants file first so files in the lib directory can use it
  require './lib/constants.rb'
  puts "+ Loaded file lib/constants.rb"

  # Loads files from lib directory in parent
  Dir['./lib/**/*.rb'].sort.each do |path|
    next if path == "./lib/constants.rb"
    require path
    puts "+ Loaded file #{path[2..-1]}"
  end

  COMMAND_LOGGER = CommandLogger.new(BOT)

  puts 'Done.'

  crystal_blacklist = ["Giveaways", "VoiceChats", "BotOperations"]
  
  # Load all crystals, preloading their modules if they are nested within subfolders
  ENV['CRYSTALS_TO_LOAD'].split(',').each do |path|
    crystal_name = path.camelize.split('::')[2..-1].join('::').sub('.rb', '')
    next if crystal_blacklist.include?(crystal_name)
    parent_module = crystal_name.split('::')[0..-2].reduce(self) do |memo, name|
      if memo.const_defined? name
        memo.const_get name
      else
        submodule = Module.new
        memo.const_set(name, submodule)
        submodule
      end
    end
    load path
    BOT.include! self.const_get(crystal_name)
    puts "+ Loaded crystal #{crystal_name}"
  end

  BOT.include! BotOperations

  puts "Starting bot with logging mode #{config[:log_mode]}..."
  BOT.ready { puts 'Bot started!' }

  # After loading all desired crystals, run the bot
  BOT.run
end
