require_relative './commands/banned_words.rb'
require_relative './commands/dm_message.rb'
require_relative './commands/ignored_channels.rb'
require_relative './utilities.rb'

# Crystal: WordFilter - Removes messages that contain banned words. Words can be added to the banned word list by a
# mod. The message to be displayed upon deletion can be changed by a mod as well.
module Bot::Moderation::WordFilter::WordFilterMain
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  extend Bot::Moderation::WordFilter::Utilities
  include Bot::Moderation::WordFilter::Utilities::Constants
  include Bot::Models
  include Constants

  # Shorthand constants for the modules in the 'commands' directory
  BannedWords = Bot::Moderation::WordFilter::Commands::BannedWords
  DmMessage = Bot::Moderation::WordFilter::Commands::DmMessage
  IgnoredChannels = Bot::Moderation::WordFilter::Commands::IgnoredChannels

  module_function

  def mentions_contain_banned_word?(mentions, banned_word)
    # Extracts all the user mentions from the 'mentions' array and formats each of them like this: Username#5353 (example)
    mentions = mentions.select{ |mention| mention.respond_to?(:offline?) }.map!(&:distinct)
    return mentions.any?{ |user| user.downcase.include?(banned_word) }
  end

  def contains_banned_word?(message, banned_word)
    if !message.content.nil?
      mentions = Bot::BOT.parse_mentions(message.content)
      if message.content.downcase =~ /(\b|_)#{banned_word}(\b|_|s)|:.*#{banned_word}.*:/ || 
        mentions_contain_banned_word?(mentions, banned_word)
      then 
        return true
      end
    end

    false
  end

  # Code that executes for message events and message edit events
  def check_for_banned_words(event)
    return if event.user.id == Bot::BOT.profile.id || event.server.nil?

    words = []
    DB[:banned_words].select_map(:word).each do |banned_word|
      if contains_banned_word?(event.message, banned_word)
        words.push(banned_word)
      end
    end

    if !(words.empty?)
      # Saves the message content to a variable so it doesn't have to be pulled from the deleted message object later on
      message_content = event.message.content

      event.message.delete
      event.respond "**Your message was deleted because it contained banned words.**"

      dm_message_sent = false
      begin
        event.user.dm(
          "**#{DB[:word_filter_message].get(:message)}**" +
          "\n**Your message:** #{message_content}" +
          "\n**Banned word(s):** #{words.join(", ")}"
        )
      rescue Discordrb::Errors::NoPermission
      else
        dm_message_sent = true
      end

      automod_log_channel = event.bot.channel(ENV['AUTOMOD_LOG_ID'])

      message = automod_log_channel.send_embed do |embed|
        embed.author = {
          name: event.user.distinct,
          icon_url: event.user.avatar_url
        }
        embed.description = "A message was deleted from #{event.channel.mention} because it contained banned words."
        embed.add_field(name: "Message Content", value: message_content)
        embed.add_field(name: "Banned Word(s)", value: words.join(", "))
        embed.color = "#e12a2a"
        embed.timestamp = Time.now
        embed.footer = {
          text: "User ID: #{event.user.id}"
        }

        unless dm_message_sent
          embed.add_field(
            name: "Additional Notes", 
            value: "A DM warning couldn't be sent to this user because they have DM's turned off for this server."
          )
        end
      end

      PunishmentLog.create(
        user_id: event.user.id,
        time: message.creation_time.to_i,
        responsible_moderator_id: 655309881993330698, # Zym
        type: "Auto-Moderator (Word Filter)",
        reason: "Used banned word(s) `#{words.join(", ")}`.\nFor more information about the offense, " +
                "view the log here (the link may be dead if the log was deleted): #{message.link}"
      )
    end
  end

  message do |event|
    next if IGNORED_CHANNELS[channel_id: event.channel.id]
    check_for_banned_words(event)
  end

  message_edit do |event|
    next if IGNORED_CHANNELS[channel_id: event.channel.id]
    check_for_banned_words(event)
  end

  command :bannedwords, aliases: [:bw], min_args: 1 do |event, option, *words|
    Bot::COMMAND_LOGGER.log(event, words.unshift(option: option))
    words.shift
    break unless (recipient_or_member?(event.user)).has_permission?(:mod) || option.downcase == "list"

    if words.empty? && (option.downcase == "add" || option.downcase == "remove" || option.downcase == "delete")
      event << "**Your command is missing a list of words to either add or remove!**"
      break
    end

    BannedWords.set_event(event)

    case option.downcase
    when "add" then BannedWords.add(words)
    when "remove", "delete" then BannedWords.remove(words)
    when "list" then BannedWords.list
    when "clear" then BannedWords.clear
    end
  end

  command :dmmessage, aliases: [:message, :dm], min_args: 1 do |event, option, *message|
    Bot::COMMAND_LOGGER.log(event, message.unshift(option: option))
    message.shift
    break unless event.user.has_permission?(:mod)

    if message.empty? && option.downcase == "set"
      event << "**Your command is missing the DM message you want to replace the current one with!**"
      break
    end

    DmMessage.set_event(event)

    case option.downcase
    when "set" then DmMessage.set(message)
    when "get" then DmMessage.get
    when "reset" then DmMessage.reset
    end
  end

  command :ignoredchannels, aliases: [:ignore, :ignored], min_args: 1 do |event, option, *channels|
    Bot::COMMAND_LOGGER.log(event, channels.unshift(option: option))
    channels.shift
    break unless event.user.has_permission?(:mod)

    # The 'list' and 'clear' options do not require any channels to be provided as arguments
    if option.downcase != "list" && option.downcase != "clear"
      channels.map!{ |channel| Bot::BOT.parse_mention(/<#\d+>/ =~ channel ? channel : "<##{channel}>") }
      channels.reject!{ |channel| channel.nil? }
      if channels.empty?
        event.respond "**All of the channels you provided were invalid. Make sure that you give valid ID's or channel mentions when using this command.**"
        break
      end
    end

    IgnoredChannels.set_event(event)

    case option.downcase
    when "add" then IgnoredChannels.add(channels)
    when "remove", "delete" then IgnoredChannels.remove(channels)
    when "list" then IgnoredChannels.list
    when "clear" then IgnoredChannels.clear
    end
  end
end