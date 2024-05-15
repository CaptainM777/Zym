# Crystal: Moderation - Contains all files with features allowing mods to moderate the server using the bot.
# Crystal: ModerationMain - Main file for this directory. Includes the core moderation commands like 'warn', 'mute',
# 'ban', and 'purge'. All other commands and event listeners in this file are related to the functionality of the 
# aforementioned commands and the logging of moderation actions.
module Bot::Moderation::ModerationMain
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants
  include Bot::Models

  ban_command_used = false

  module_function

  # Takes the given time string argument, in a format similar to '5d2h15m45s' and returns its representation in
  # a number of seconds.
  # @param  [String]  str the string to parse into a number of seconds
  # @return [Integer]     the number of seconds the given string is equal to, or 0 if it cannot be parsed properly
  def parse_time(str)
    seconds = 0
    str.scan(/\d+ *[Dd]/).each { |m| seconds += (m.to_i * 24 * 60 * 60) }
    str.scan(/\d+ *[Hh]/).each { |m| seconds += (m.to_i * 60 * 60) }
    str.scan(/\d+ *[Mm]/).each { |m| seconds += (m.to_i * 60) }
    str.scan(/\d+ *[Ss]/).each { |m| seconds += (m.to_i) }
    seconds
  end

  # Takes the given number of seconds and converts into a string that describes its length (i.e. 3 hours,
  # 4 minutes and 5 seconds, etc.)
  # @param  [Integer] secs the number of seconds to convert
  # @return [String]       the length of time described
  def time_string(secs)
    dhms = ([secs / 86400] + Time.at(secs).utc.strftime('%H|%M|%S').split("|").map(&:to_i)).zip(['day', 'hour', 'minute', 'second'])
    dhms.shift while dhms[0][0] == 0
    dhms.pop while dhms[-1][0] == 0
    dhms.map! { |(v, s)| "#{v} #{s}#{v == 1 ? nil : 's'}" }
    return dhms[0] if dhms.size == 1
    "#{dhms[0..-2].join(', ')} and #{dhms[-1]}"
  end

  def log_unmute(user, reason)
    Bot::BOT.channel(ENV['MOD_LOG_ID']).send_embed do |embed|
      embed.author = {
          name: "UNMUTE | User: #{user.display_name} (#{user.distinct})",
          icon_url: user.avatar_url
      }
      embed.description = "🔈 **#{user.mention}** was unmuted."
      embed.add_field(name: "Reason", value: reason)
      embed.timestamp = Time.now
      embed.color = 0xFFD700
    end
  end

  def log_unban(user, reason)
    Bot::BOT.channel(ENV['MOD_LOG_ID']).send_embed do |embed|
      embed.author = {
          name: "UNBAN | User: #{user.display_name} (#{user.distinct})",
          icon_url: user.avatar_url
      }
      embed.description = "🔨 **#{user.mention}** was unbanned."
      embed.add_field(name: "Reason", value: reason)
      embed.timestamp = Time.now
      embed.color = 0xFFD700
    end
  end

  command :warn, aliases: [:warning] do |event, *args|
    Bot::COMMAND_LOGGER.log(event, args)

    event_argument = Discordrb::Commands::CommandEvent.new(event.message, event.bot)

    if args.size > 1
      event.bot.execute_command(:nwarn, event_argument, args) if args.size > 1
      break
    end

    # Breaks unless user is moderator and given user is valid, defining user variable if so
    break unless event.user.has_permission?(:mod) && (user = SERVER.get_user(args.join(' ')))

    event.respond "Prompt-based commands such as this one will be removed in the future. Consider using the argument-based " +
                  "version instead: `-warn <user ID> <reason>`\n\nExample usage: `-warn 260600155630338048 Using too many curse words`"

    reason_prompt = "**What should the warning message be?** Press ❌ to cancel."
    reason_response = event.message.prompt(reason_prompt, '❌', timeout: 900, clean: true)

    break if reason_response.nil?

    reason = reason_response.content

    reason_response.delete

    PunishmentLog.create(
      user_id: user.id,
      time: Time.now.to_i,
      responsible_moderator_id: event.user.id,
      type: "Warning",
      reason: reason
    )

    # Sends log embed to #mod_log
    event.bot.channel(ENV['MOD_LOG_ID']).send_embed do |embed|
      embed.author = {
          name: "WARNING | User: #{user.display_name} (#{user.distinct})",
          icon_url: user.avatar_url
      }
      embed.description = "⚠ #{user.mention} was issued a warning by #{event.user.mention} (#{event.user.distinct})."
      embed.add_field(name: "Reason", value: reason)
      embed.timestamp = Time.now
      embed.color = 0xFFD700
    end

    begin
      user.dm.send_embed do |e|
        e.color = "#f7d469"
        e.description = "⚠ You've received a warning from the staff."
        e.add_field(name: "Reason", value: reason)
      end
    rescue Discordrb::Errors::NoPermission
      event << "**A warning couldn't be sent to this user because their DM's are closed. A chat should " +
               "probably be opened up so that the warn can be explained to them.**"
    else
      event << "**Sent warning to #{user.distinct}.**"
    end
  end

  command :mute do |event, *args|
    Bot::COMMAND_LOGGER.log(event, args)

    event_argument = Discordrb::Commands::CommandEvent.new(event.message, event.bot)
    
    if args.size > 1
      event.bot.execute_command(:nmute, event_argument, args)
      break
    end

    # Breaks unless user is moderator and given user is valid
    break unless event.user.has_permission?(:mod) && (user = SERVER.get_user(args.join(' ')))

    event.respond "Prompt-based commands such as this one will be removed in the future. Consider using the argument-based " +
                  "version instead: `-mute <user ID> <duration> <reason>`\n\nExample usage: `-mute 260600155630338048 12h Using too many curse words`"

    length_prompt = "**How long should the mute last? Respond with i for an indefinite mute.** Press ❌ to cancel."
    mute_length_response = event.message.prompt(length_prompt, '❌', timeout: 900, clean: true) do |response|
      parsed_time = parse_time(response)

      if response.downcase != "i" && parsed_time < 3600
        event.send_temp("That's not a valid length of time! Mutes have to be at least 1 hour in length.", 10)
        next
      end

      response.downcase! if response.downcase == "i"

      true
    end

    break if mute_length_response.nil?

    mute_length = mute_length_response.content == "i" ? "i" : parse_time(mute_length_response.content)

    reason_prompt = "**What should the mute reason be? This is required.**"
    mute_reason_response = event.message.prompt(reason_prompt, '❌', timeout: 900, clean: true)

    break if mute_reason_response.nil?

    mute_reason = mute_reason_response.content

    # Deletes messages
    mute_length_response.delete
    mute_reason_response.delete

    PunishmentLog.create(
      user_id: user.id,
      time: Time.now.to_i,
      responsible_moderator_id: event.user.id,
      type: "Mute",
      length: mute_length == "i" ? nil : mute_length,
      reason: mute_reason
    )

    # Sends log embed to #mod_log
    event.bot.channel(ENV['MOD_LOG_ID']).send_embed do |embed|
      embed.author = {
          name: "MUTE | User: #{user.display_name} (#{user.distinct})",
          icon_url: user.avatar_url
      }
      embed.description = "🔇 #{user.mention} was muted by #{event.user.mention} (#{event.user.distinct})."
      embed.add_field(name: "Duration", value: mute_length == "i" ? "Indefinite" : "#{time_string(mute_length)} until <t:#{(Time.now + mute_length).to_i}:f>")
      embed.add_field(name: "Reason", value: mute_reason)
      embed.timestamp = Time.now
      embed.color = 0xFFD700
    end

    Mute[user.id].destroy if Mute[user.id]

    Mute.create(
      id: user.id,
      reason: mute_reason,
      start_time: Time.now,
      end_time: mute_length == "i" ? nil : Time.now + mute_length
    )

    # Tries to send a DM to the user. If they left the server, the command terminates. If they are still on the server
    # but have DM's turned off for server members, they are still muted.
    begin
      user.dm.send_embed do |e|
        e.color = "#f7d469"
        e.description = "🔇 You've been muted by the staff. If you wish to discuss your mute with the staff, " +
                        "DM <@842857116631826482> (Aaravos' Mirror)."
        e.add_field(name: "Duration", value: mute_length == "i" ? "Indefinite" : "#{time_string(mute_length)} until <t:#{(Time.now + mute_length).to_i}:f>")
        e.add_field(name: "Reason", value: mute_reason)
      end
    rescue Discordrb::Errors::NoPermission
      event.respond "Error DM'ing user. They may have their DM's turned off for this server, or they left. " +
      "If they are still on the server, they will be given a timed mute."
      break if SERVER.member(user.id).nil?
    end

    event.respond "**Muted #{user.distinct}#{mute_length == "i" ? "." : " for #{time_string(mute_length)} until <t:#{(Time.now + mute_length).to_i}:f>."}**"
    user.add_role(ENV['MUTED_ROLE_ID'])
  end

  command :purge, min_args: 1 do |event, *args|
    Bot::COMMAND_LOGGER.log(event, args)
    break unless event.user.has_permission?(:mod)

    amount_to_delete, after_id, before_id = nil
    after_id_message, before_id_message = nil

    if (2..100).include?(args[0].to_i)
      amount_to_delete = args[0].to_i
    elsif ["after", "range"].include?(args[0].downcase)
      amount_to_delete = 100
      after_id = args[1].to_i
      after_id_message = event.channel.load_message(after_id)

      if after_id_message.nil?
        break "**Your first message ID argument is invalid.**"
      end

      if args[0].downcase == "range"
        before_id = args[2].to_i
        before_id_message = event.channel.load_message(before_id)

        if before_id_message.nil?
          break "**Your second message ID argument is invalid.**"
        end
      end
    end

    if amount_to_delete.nil?
      break "**The number of messages you want to delete is outside of the allowed range (2-100).**"
    end

    if !after_id_message.nil? && !before_id_message.nil?
      if after_id_message.timestamp > before_id_message.timestamp
        event.respond(
          "**Your argument order for `-purge range` is wrong. The first argument should be the " +
          "first message ID in the range and the last argument should be the last message ID in the range.**"
        )
        break
      end
    end

    event.message.delete
    total_messages_deleted = event.channel.purge_messages(amount_to_delete, before_id, after_id)
    event.send_temp("**Deleted #{total_messages_deleted} messages.**", 5)
  end

  command :ban do |event, *args|
    Bot::COMMAND_LOGGER.log(event, args)

    event_argument = Discordrb::Commands::CommandEvent.new(event.message, event.bot)

    if args.size > 1
      event.bot.execute_command(:nban, event_argument, args)
      break
    end

    break unless event.user.has_permission?(:mod)
    
    user = SERVER.get_user(args.join(' ')) || Bot::BOT.user(args.join(' '))

    event.respond "Prompt-based commands such as this one will be removed in the future. Consider using the argument-based " +
                  "versions instead: `Indefinite ban: -ban <user ID> <reason>`, `Temporary ban: -ban <user ID> <duration> <reason>`" +
                  "\n\nExample usage: `-ban 260600155630338048 Using too many curse words`, `-ban 260600155630338048 3d Advertising a server`"

    if user.nil?
      event.respond "**User not found.**" 
      break
    end

    # Sets this variable to 'true' so the user_ban event handler doesn't register the ban
    ban_command_used = true

    # Storage for prompt responses, which are all deleted at the end of the command
    responses = []

    ban_type = nil
    ban_type_prompt = "Is this a temporary ban or a permanent ban? Reply with the number that corresponds to the option you want. " +
                      "Use '❌' to cancel the command.\n**1) Temporary ban**\n**2) Permanent ban**"
    ban_type_response = event.message.prompt(ban_type_prompt, '❌', timeout: 900, clean: true) do |response|
      case response
      when "1"
        ban_type = :temp
      when "2"
        ban_type = :perm
      else
        event.send_temp("**Invalid value. Try again.**", 5)
        next
      end

      true
    end

    break if ban_type_response.nil?

    responses << ban_type_response

    days_deleted_prompt = "**How many days of messages would you like Zym to delete? Enter 0 if you don't want any deleted.**"
    days_deleted_response = event.message.prompt(days_deleted_prompt, '❌', timeout: 900, clean: true) do |response|
      if !(0..7).include?(response.to_i)
        event.send_temp("Invalid input. Enter a number between 0 and 7, inclusive.", 5)
        next
      end

      true
    end

    break if days_deleted_response.nil?

    responses << days_deleted_response

    days_deleted = days_deleted_response.content

    reason_prompt = "**Include the reason for your ban. This is required.**"
    reason_response = event.message.prompt(reason_prompt, '❌', timeout: 900, clean: true) do |response|
      if response.length > 512
        event.send_temp("Your ban reason is too long! Keep it under 512 characters! Current character count: #{response.length}", 10)
        next
      end

      true
    end

    break if reason_response.nil?

    responses << reason_response

    reason = reason_response.content

    if ban_type == :perm
      PunishmentLog.create(
        user_id: user.id,
        time: Time.now.to_i,
        responsible_moderator_id: event.user.id,
        type: "Permanent Ban",
        days_deleted: days_deleted,
        reason: reason
      )

      event.bot.channel(ENV['MOD_LOG_ID']).send_embed do |embed|
        embed.author = {
            name: "BAN | User: #{user.display_name} (#{user.distinct})",
            icon_url: user.avatar_url
        }
        embed.description = "🔨 #{user.mention} was banned from the server by #{event.user.mention} (#{event.user.distinct})."
        embed.add_field(name: "Days of Messages Deleted", value: days_deleted)
        embed.add_field(name: "Reason", value: (reason.empty? ? "None." : reason))
        embed.timestamp = Time.now
        embed.color = 0xFFD700
      end

      begin
        user.dm.send_embed do |e|
          e.color = "#e12a2a"
          e.description = "🔨 You've been banned from the server. If you wish to appeal your ban, join the " +
                          "ban appeal server: https://discord.gg/59fNWZmjA2"
          e.add_field(name: "Reason", value: reason)
        end
      rescue Discordrb::Errors::NoPermission
        event.respond "**Error DM'ing user. They either have DM's turned off for this server or they left. They will still be banned.**"
      end

      ban_message = "**Banned #{user.distinct}.**"
    else
      ban_length_prompt = "**How long would you like the temporary ban to last? If you're going to give a ban length, format days with 'd', hours with 'h', minutes with 'm', " +
                          "and seconds with 's'.** `Examples: 5d6h (5 days and 6 hours), 10d (10 days), 3d10h50m15s (3 days, 10 hours, 50 minutes, and 15 seconds).`"
      ban_length_response = event.message.prompt(ban_length_prompt, '❌', timeout: 900, clean: true) do |response|
        parsed_time = parse_time(response)

        if parsed_time < 86400
          event.send_temp("That's not a valid length of time! Temporary bans have to be at least 1 day in length.", 10)
        end

        true
      end

      break if ban_length_response.nil?

      responses << ban_length_response

      total_seconds = parse_time(ban_length_response.content)

      temp_ban_end = Time.now + total_seconds

      PunishmentLog.create(
        user_id: user.id,
        time: Time.now.to_i,
        responsible_moderator_id: event.user.id,
        type: "Temporary Ban",
        length: total_seconds,
        days_deleted: days_deleted,
        reason: reason
      )

      event.bot.channel(ENV['MOD_LOG_ID']).send_embed do |embed|
        embed.author = {
            name: "TEMPORARY BAN | User: #{user.display_name} (#{user.distinct})",
            icon_url: user.avatar_url
        }
        embed.description = "🔨 #{user.mention} was temporarily banned from the server by #{event.user.mention} (#{event.user.distinct})."
        embed.add_field(name: "Days of Messages Deleted", value: days_deleted)
        embed.add_field(name: "Duration", value: "#{time_string(total_seconds)} until <t:#{temp_ban_end.to_i}:F>")
        embed.add_field(name: "Reason", value: (reason.empty? ? "None." : reason))
        embed.timestamp = Time.now
        embed.color = 0xFFD700
      end

      begin
        user.dm.send_embed do |e|
          e.color = "#e12a2a"
          e.description = "🔨 You've been banned from the server. If you wish to appeal your ban, join the " +
                          "ban appeal server: https://discord.gg/59fNWZmjA2"
          e.add_field(name: "Duration", value: "#{time_string(total_seconds)} until <t:#{temp_ban_end.to_i}:f>")
          e.add_field(name: "Reason", value: reason)
        end
      rescue Discordrb::Errors::NoPermission
        event.respond "**Error DM'ing user. They either have DM's turned off for this server or they left. They will still be banned.**"
      end

      TempBan[user.id].destroy if TempBan[user.id]

      TempBan.create(id: user.id, end_time: temp_ban_end)

      ban_message = "**Temporarily banned #{user.distinct}.**"
    end

    responses.each(&:delete)

    begin
      SERVER.ban(user, days_deleted, reason: reason)
    rescue Discordrb::Errors::NoPermission
      event.respond "**The bot doesn't have permission to ban #{user.distinct}!**"
    else
      event.respond ban_message
    end

    sleep 5

    # Sets this variable back to false so it doesn't mess up future manual bans
    ban_command_used = false
    nil
  end
end
