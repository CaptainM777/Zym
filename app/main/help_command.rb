require 'yaml'

# Crystal: HelpCommand - Generates parts of the help command using pre-written portions stored in a YAML file.
module Bot::HelpCommand
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  help_command = YAML.load_file 'help-command.yml'

  descriptions = help_command["descriptions"]
  footers = help_command["footers"]

  help_command.delete("descriptions")
  help_command.delete("footers")

  def self.has_one_user_command?(commands_hash)
    commands_hash.each_value do |info|
      return true unless info["mod_command?"]
    end
    false
  end

  # @param [Discordrb::Channel] channel - The channel to send the embed in.
  # @param [String] title - The top-most part of the embed. Should say either "Command List (<permission level>)"
  # or "Help: <command name>"
  # @param [String] description - If the master list is displayed, this shows how to get help on a specific command.
  # If a specific command is displayed, then this shows information about that command.
  # @param [String, nil] footer - The bottom-most part of the embed. Won't be displayed if set to nil (default value).
  # If a specific command is displayed, then this will show how to bring up the master list again.
  # @param [Array<Hash>, nil] fields - Contains all the command categories and their respective commands. Won't
  # be displayed if set to nil (default value).
  def self.send_embed(channel, title, description, footer: nil, fields: nil)
    channel.send_embed do |embed|
      embed.title = title
      embed.description = description
      fields.each{ |field| embed.add_field(name: field[:name], value: field[:value]) } unless fields.nil?
      embed.footer = { text: footer } unless footer.nil?
      embed.color = 0xFFD700
    end
  end

  command :help do |event, *args|
    Bot::COMMAND_LOGGER.log(event, args)
    type = args.join(" ").empty? ? "master" : args.join(" ")

    if type == "master"
      fields = []
      help_command.each do |category, commands|
        category = "#{category.split("-").map!(&:capitalize).join(" ")}"

        commands_to_show = commands.map do |command, properties|
          next if !event.user.has_permission?(:mod) && properties["mod_command?"]
          "`#{command}`"
        end.compact

        next if commands_to_show.empty?

        fields << { name: category, value: commands_to_show.join(", ") }
      end

      event.send_embed do |e|
        e.color = 0xFFD700
        e.title = "__Command List__"
        e.description = descriptions["master-list"]
        e.fields = fields
        e.footer = { text: footers["master-list"] }
      end
    else
      command_name = type.downcase
      help_command.each_value do |commands|
        command = commands.select{ |command, properties| command == command_name }

        next if command.empty? || # Command can't be found
                (!event.user.has_permission?(:mod) && command[command_name]["mod_command?"]) # Command is mod-only and user is not a mod

        command_properties = command.values[0]
        command_description = command_properties["description"]

        event.send_embed do |e|
          e.color = 0xFFD700
          e.title = "Help: -#{command_name}"
          e.description = command_description

          command_properties.each do |name, property|
            next if ["description", "mod_command?"].include?(name)
            e.add_field(name: name.split("_").map!(&:capitalize).join(" "), value: property)
          end 

          e.footer = { text: footers["specific"] }
        end

        break
      end
    end

    nil
  end
end