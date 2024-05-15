# Crystal: Cams - Allows users to send messages of their choosing to a 'storybook' channel by reacting with the 'camera' 
# emote. If the minimum number of 'camera' emotes are met, then that message will be sent to the 'storybook' channel.
module Bot::Cams
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  cammed_messages = DB[:cammed_messages]
  cam_requirement = DB[:cam_requirement]
  ignored_channels = DB[:cams_channels_blacklist]

  module_function

  def self.remove_spoilers(message)
    pattern = /\|\|.+\|\|/
    while pattern.match?(message)
      message.gsub!(pattern, message.slice(pattern).delete("|"))
    end
    return message
  end

  def self.put_quotes_in_spoilers(quotes)
    return quotes.map!{ |quote| quote.replace("> || #{quote[2..-1]} ||") }
  end

  def self.validate_channels(channels)
    channels.map! do |channel|
      validated_channel = Bot::BOT.get_channel(channel)
      validated_channel.nil? ? nil : validated_channel
    end
    channels.reject!{ |channel| channel.nil? }
    channels
  end
      
  def send_message_to_storybook(message)
    attachment = message.attachments[0]
    content = message.content
    if message.channel.nsfw?
      inner_content = remove_spoilers(content)
      # The 'scan' method here only returns quotes with actual content instead of quotes with actual content and
      # quotes with just newlines; accounting for quotes with newlines returns an array of arrays, instead of an array
      # of strings, which throws an error when passed into the 'put_quotes_in_spoilers' method.
      quotes = put_quotes_in_spoilers(inner_content.scan(/^> .+$/))
      # Removes quotes from the message (including quotes that are just newlines)
      inner_content.gsub!(/^> (.+$|\n)/, '')
      inner_content.lstrip!

      if attachment
        content = "#{quotes.join("\n")}\n|| #{inner_content} #{attachment.url} ||"
        attachment = nil # 'attachment' is set to nil so it doesn't get added to the embed
      else
        content = "#{quotes.join("\n")}\n|| #{inner_content} ||"
      end
    end
    author = message.author
    channel = message.channel
    message_link = message.jump_url

    message.delete_reaction_all('📷')

    Bot::BOT.channel(ENV['STORYBOOK_ID']).send_embed do |embed|
      embed.author = {
        name: (author.nickname.nil? ? "#{author.username}" : "#{author.username} (#{author.nickname})"),
        icon_url: author.avatar_url
      }
      embed.description = content
      embed.add_field(name: "Message Link", value: "[Jump to Post](#{message_link})")
      embed.image = Discordrb::Webhooks::EmbedImage.new(url: (attachment.url unless attachment.nil?))
      embed.footer = { text: "##{channel.name}" }
      embed.timestamp = Time.now
      embed.color = 0xFFD700
    end
  end

  command :cams, min_args: 1, usage: "-cams <number>" do |event, *args|
    Bot::COMMAND_LOGGER.log(event, args)
    break unless event.user.has_permission?(:mod)
    new_requirement = args[0].to_i
    cam_requirement.update(num_of_cams: new_requirement)
    event.respond "**Set the minimum number of cams to #{new_requirement}.**"
  end

  command :getcams do |event|
    Bot::COMMAND_LOGGER.log(event)
    break unless event.user.has_permission?(:mod)
    event.respond "**Minimum number of cams set to: #{cam_requirement.get(:num_of_cams)}**"
  end

  command :addchannels, aliases: [:addchannel] do |event, *channels|
    Bot::COMMAND_LOGGER.log(event, channels)
    break unless event.user.has_permission?(:mod)
    channels = validate_channels(channels)

    if channels.empty?
      event.respond "**All of the channels you provided were invalid. Make sure that you give valid ID's or channel mentions when using this command.**"
      break
    end

    channels.map! do |channel|
      begin
        ignored_channels.insert(id: channel.id)
      rescue Sequel::UniqueConstraintViolation
        event << "**#{channel.mention} is already ignored!**"
        nil
      else
        channel.mention
      end
    end

    channels.reject!{ |channel| channel.nil? }

    event << "The following channels have been successfully ignored: #{channels.join(", ")}" unless channels.empty?
  end

  command :removechannels, aliases: [:removechannel] do |event, *channels|
    Bot::COMMAND_LOGGER.log(event, channels)
    break unless event.user.has_permission?(:mod)
    channels = validate_channels(channels)

    if channels.empty?
      event.respond "**All of the channels you provided were invalid. Make sure that you give valid ID's or channel mentions when using this command.**"
      break
    end

    channels.map! do |channel|
      if ignored_channels[id: channel.id]
        ignored_channels.where(id: channel.id).delete
        channel.mention
      else
        event << "**#{channel.mention} isn't an ignored channel!**"
        nil
      end
    end

    channels.reject!{ |channel| channel.nil? }

    event << "The following channels have been successfully unignored: #{channels.join(", ")}" unless channels.empty?
  end

  command :showignoredchannels, aliases: [:showchannels] do |event|
    blacklisted_channels = ignored_channels.select_map(:id)
                                           .map!{ |id| Bot::BOT.channel(id)&.mention }
                                           .reject{ |c| c.nil? }
    break "**There are no ignored channels!**" if blacklisted_channels.empty?
    event << "Channels currently ignored: #{blacklisted_channels.join(", ")}"
  end

  command :clearignoredchannels, aliases: [:clearchannels] do |event|
    ignored_channels.delete
    event << "**All ignored channed have been removed.**"
  end

  reaction_add(emoji: '📷') do |event|
    next if ignored_channels[id: event.channel.id]
    cam = event.message.reactions.find{ |r| r.name == '📷' }
    if cam.count >= cam_requirement.get(:num_of_cams) && event.channel.id != ENV['STORYBOOK_ID'].to_i
      begin
        cammed_messages.insert(event.message.id, event.message.author.id, event.message.author.distinct, event.message.timestamp)
      rescue Sequel::UniqueConstraintViolation
      else
        send_message_to_storybook(event.message)
      end
    else
      next
    end
  end
end