# Crystal: NewModerationMain

module Bot::Moderation::NewModerationMain
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants
  include Bot::Models

  def self.error_embed(title)
    Discordrb::Webhooks::Embed.new(color: "#e12a2a", description: "❌ #{title}")
  end

  def self.log_unmute(user, reason)
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

  def self.log_unban(user, reason)
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
  
  command :nwarn, min_args: 2 do |event, user_id, *reason|
    break unless event.user.has_permission?(:mod)

    user = event.bot.member(event.server, user_id)
    if user.nil?
      event.message.reply!("", embed: error_embed("User not found on the server"))
      break
    end

    reason = reason.join(" ")

    PunishmentLog.create(
      user_id: user.id,
      time: Time.now.to_i,
      responsible_moderator_id: event.user.id,
      type: "Warning",
      reason: reason
    )

    event.bot.channel(ENV['MOD_LOG_ID']).send_embed do |e|
      e.author = {
          name: "WARNING | User: #{user.display_name} (#{user.distinct})",
          icon_url: user.avatar_url
      }
      e.description = "⚠ #{user.mention} was issued a warning by #{event.user.mention} (#{event.user.distinct})."
      e.add_field(name: "Reason", value: reason)
      e.timestamp = Time.now
      e.color = 0xFFD700
    end

    event.channel.start_typing

    begin
      user.dm.send_embed do |e|
        e.color = "#f7d469"
        e.description = "⚠ You've received a warning from the staff."
        e.add_field(name: "Reason", value: reason)
      end
    rescue Discordrb::Errors::NoPermission
      event.send_embed("", nil, nil, false, false, event.message) do |e|
        e.color = "#e12a2a"
        e.description = "⚠ A warning couldn't be sent to this user because their DM's are closed. A Mirror chat should " +
                        "probably be opened up so that the warn can be explained to them."
      end
    else
      event.send_embed("", nil, nil, false, false, event.message) do |e|
        e.color = "#6df67e"
        e.description = "⚠ Warned #{user.distinct}"
      end
    end
  end

  command :nmute, min_args: 1 do |event, user_id, *args|
    break unless event.user.has_permission?(:mod)

    user = event.bot.member(event.server, user_id)
    if user.nil?
      event.message.reply!("", embed: error_embed("User not found on the server"))
      break
    end

    if args[0] =~ /\d+ *([Dd]|[Hh]|[Mm]|[Ss])/
      mute_length = parse_time(args[0])

      if mute_length < 3600
        event.message.reply!("", embed: error_embed("Invalid length of time! Mutes have to be at least 1 hour in length."))
        break
      end
    end

    if args[1..-1]&.empty? || args.empty?
      reason = "None given."  
    else 
      reason = mute_length ? args[1..-1].join(" ") : args.join(" ")
    end

    event.bot.channel(ENV['MOD_LOG_ID']).send_embed do |e|
      e.author = {
          name: "MUTE | User: #{user.display_name} (#{user.distinct})",
          icon_url: user.avatar_url
      }
      e.description = "🔇 #{user.mention} was muted by #{event.user.mention} (#{event.user.distinct})."
      e.add_field(name: "Duration", value: mute_length.nil? ? "Indefinite" : "#{time_string(mute_length)} until <t:#{(Time.now + mute_length).to_i}:f>")
      e.add_field(name: "Reason", value: reason)
      e.timestamp = Time.now
      e.color = 0xFFD700
    end

    event.channel.start_typing

    begin
      user.dm.send_embed do |e|
        e.color = "#f7d469"
        e.description = "🔇 You've been muted by the staff. If you wish to discuss your mute with the staff, " +
                        "DM <@842857116631826482> (Aaravos' Mirror)."
        e.add_field(name: "Duration", value: mute_length.nil? ? "Indefinite" : "#{time_string(mute_length)} until <t:#{(Time.now + mute_length).to_i}:f>")
        e.add_field(name: "Reason", value: reason)
      end
    rescue Discordrb::Errors::NoPermission
      note_to_mod = "A mute reason could not be sent to this user because their DM's are closed. They will still be muted, " +
                    "but a Mirror chat should probably be opened up so the situation can be explained."

      if event.server.member(user.id).nil?
        event.message.reply!("", embed: error_embed("This user has left the server and cannot be muted."))
        break
      end
    end

    PunishmentLog.create(
      user_id: user.id,
      time: Time.now.to_i,
      responsible_moderator_id: event.user.id,
      type: "Mute",
      length: mute_length,
      reason: reason
    )

    Mute[user.id].destroy if Mute[user.id]

    Mute.create(
      id: user.id,
      reason: reason,
      start_time: Time.now,
      end_time: mute_length.nil? ? mute_length : Time.now + mute_length
    )


    event.send_embed("", nil, nil, false, false, event.message) do |e|
      e.color = "#6df67e"
      e.description = "🔇 Muted #{user.distinct} " +
                      "#{mute_length.nil? ? "" : "for #{time_string(mute_length)} until <t:#{(Time.now + mute_length).to_i}:f>"}"
      e.add_field(name: "Note to Moderator", value: note_to_mod) if note_to_mod
    end

    user.add_role(ENV['MUTED_ROLE_ID'])
  end
  
  # Checks every 30 seconds to see if any mutes have ended
  SCHEDULER.every '30s', first: :now do |t|
    Mute.all.each do |mute|
      next if mute.end_time.nil?

      if Time.now > mute.end_time
        mute.destroy
        muted_user = Bot::BOT.member(SERVER, mute.id)
        muted_user.remove_role(ENV['MUTED_ROLE_ID']) unless muted_user.nil?
        log_unmute(muted_user, "Muted time period ended")
      end
    end
  end

  # Ends the mute early if the muted role is removed; changed to be consistent with Dyno mutes
  member_update do |event|
    next unless Mute[event.user.id] && !event.user.role?(ENV['MUTED_ROLE_ID'])
    Mute[event.user.id].destroy
  end

  command :unmute, min_args: 1 do |event, user_id|
    Bot::COMMAND_LOGGER.log(event, user_id)

    break unless event.user.has_permission?(:mod) 
    
    user = event.bot.member(event.server, user_id)
    if user.nil?
      event.message.reply!("", embed: error_embed("User not found on the server"))
      break
    end

    event.channel.start_typing

    log_unmute(user, "Unmuted by #{event.user.mention} (#{event.user.distinct})")

    user.remove_role(ENV['MUTED_ROLE_ID'])

    Mute[user.id].destroy if Mute[user.id]

    event.send_embed("", nil, nil, false, false, event.message) do |e|
      e.color = "#6df67e"
      e.description = "🔈 Unmuted #{user.distinct}"
    end
  end

  command :nban, min_args: 2 do |event, user_id, *args|
    break unless event.user.has_permission?(:mod)

    user = event.bot.user(user_id)
    if user.nil?
      event.message.reply!("", embed: error_embed("User not found"))
      break
    end

    # Ban length checking

    if args[0] =~ /\d+ *([Dd]|[Hh]|[Mm]|[Ss])/
      ban_length = parse_time(args[0])

      if ban_length < 86400
        event.message.reply!("", embed: error_embed("Invalid length of time! Temporary bans have to be at least a day in length."))
        break
      end

      temp_ban_end = Time.now + ban_length
    end

    # Days deleted checking

    days_deleted = ban_length ? args[1] : args[0]

    if days_deleted.to_i > 7 || days_deleted.to_i < 0
      event.message.reply!("", embed: error_embed("Invalid number of days to delete! This number has to be between 0 and 7, inclusive."))
      break
    end

    if days_deleted =~ /(?<!.)[0-7]{1}(?!.)/
      days_deleted = days_deleted.to_i
    else
      days_deleted = nil
    end

    # Reason checking

    if ban_length.nil? && days_deleted.nil?
      reason = args.join(" ")
    elsif ban_length.nil? || days_deleted.nil?
      reason = args[1..-1].join(" ")
    else 
      reason = args[2..-1].join(" ")
    end

    if reason.length > 512
      event.message.reply!("", embed: error_embed("Your ban reason is too long! Keep it under 512 characters! Current character count: #{reason.length}"))
      break
    end

    days_deleted = 0 if days_deleted.nil?

    PunishmentLog.create(
      user_id: user.id,
      time: Time.now.to_i,
      responsible_moderator_id: event.user.id,
      type: "#{ban_length ? "Temporary" : "Permanent"} Ban",
      length: ban_length ? ban_length : nil,
      days_deleted: days_deleted,
      reason: reason
    )

    TempBan[user.id].destroy if TempBan[user.id]

    TempBan.create(id: user.id, end_time: temp_ban_end) if ban_length

    event.bot.channel(ENV['MOD_LOG_ID']).send_embed do |e|
      e.author = {
          name: "#{ban_length ? "TEMPORARY BAN" : "BAN"} | User: #{user.display_name} (#{user.distinct})",
          icon_url: user.avatar_url
      }
      e.description = "🔨 #{user.mention} was #{ban_length ? "temporarily banned" : "banned"} "
                          "from the server by #{event.user.mention} (#{event.user.distinct})."
      e.add_field(name: "Duration", value: "#{time_string(ban_length)} until <t:#{temp_ban_end.to_i}:F>") if ban_length
      e.add_field(name: "Days of Messages Deleted", value: days_deleted)
      e.add_field(name: "Reason", value: (reason.empty? ? "None." : reason))
      e.timestamp = Time.now
      e.color = 0xFFD700
    end

    event.channel.start_typing

    begin
      user.dm.send_embed do |e|
        e.color = "#e12a2a"
        e.description = "🔨 You've been banned from **#{event.server.name}**. If you wish to appeal your ban, join the " +
                        "ban appeal server: https://discord.gg/59fNWZmjA2"
        e.add_field(name: "Duration", value: "#{time_string(ban_length)} until <t:#{temp_ban_end.to_i}:F>") if ban_length
        e.add_field(name: "Reason", value: reason)
      end
    rescue Discordrb::Errors::NoPermission
      event.send_embed("", nil, nil, false, false, event.message) do |e|
        e.color = "#e12a2a"
        e.description = "🔨 A ban reason could not be sent to this user because their DM's are either closed or they are not on " +
                        "the server. If they are still here, they will be banned."
      end
    end

    begin
      event.server.ban(user, days_deleted, reason: reason)
    rescue Discordrb::Errors::NoPermission
      event.message.reply!("", embed: error_embed("The bot doesn't have permission to ban #{user.distinct}!"))
    else
      event.send_embed("", nil, nil, false, false, event.message) do |e|
        e.color = "#6df67e"
        e.description = "🔨 Banned #{user.distinct} " +
                        "#{ban_length ? "for #{time_string(ban_length)} until <t:#{temp_ban_end.to_i}:F>" : ""}"
      end
    end
  end

  # Checks every 5 minutes to see if any temp bans have ended
  SCHEDULER.every '5m', first: :now do
    TempBan.all.each do |tb|
      if Time.now > tb.end_time
        banned_user = Bot::BOT.user(tb.id)

        if banned_user.nil?
          puts "Temp bans: Unknown user" 
          next
        end

        begin 
          SERVER.unban(banned_user)
        rescue Discordrb::Errors::UnknownError
        else
          log_unban(banned_user, "Temporary ban time period ran out")
        end

        tb.destroy
      end
    end
  end

  command :unban, min_args: 1 do |event, user_id|
    Bot::COMMAND_LOGGER.log(event, user_id)

    break unless event.user.has_permission?(:mod)

    user = event.bot.user(user_id)
    if user.nil?
      event.message.reply!("", embed: error_embed("User not found"))
      break
    end

    TempBan[user.id].destroy if TempBan[user.id]

    begin
      event.server.unban(user)
    rescue Discordrb::Errors::UnknownError
      event.message.reply!("", embed: error_embed("This user isn't banned"))
      break
    end
    
    event.channel.start_typing

    log_unban(user, "Unbanned by #{event.user.mention} (#{event.user.distinct})")

    event.send_embed("", nil, nil, false, false, event.message) do |e|
      e.color = "#6df67e"
      e.description = "🔨 Unbanned #{user.distinct}"
    end
  end

  # Logs Dyno automod violations
  message in: ENV['AUTOMOD_LOG_ID'].to_i do |event|
    next if ![155149108183695360, 168274283414421504].include?(event.user.id)
    
    automod_embed = event.message.embeds[0]
    next if automod_embed.nil? || !automod_embed.author.name.match?(/Case \d+ \| Mute \[Auto\]/)

    embed_fields = automod_embed.fields

    case_number = automod_embed.author.name.split(" ")[1]

    punished_user_id = embed_fields.filter{ |field| field.name == "User" }[0].value[/\d+/]
    responsible_moderator_id = event.user.id

    formatted_mute_length = embed_fields.filter{ |field| field.name == "Length" }[0].value.scan(/\d+ m/)[0].delete(" ")
    mute_length = parse_time(formatted_mute_length)

    type = embed_fields.filter{ |field| field.name == "Reason" }[0].value

    dyno_domain_name = event.server.id == 841384715666849803 ? "premium.dyno.gg" : "dyno.gg"

    PunishmentLog.create(
      user_id: punished_user_id,
      time: Time.now,
      responsible_moderator_id: responsible_moderator_id,
      type: type,
      length: mute_length,
      reason: "For more information, view the auto-mod log [here](#{event.message.link}). Alternatively, you can " +
              "view the log on Dyno's dashboard [here](https://#{dyno_domain_name}/manage/#{event.server.id}/logs/moderation) (case #{case_number})."
    )
  end

  member_join do |event|
    next if (Time.now - event.user.creation_time) > 300
    event.user.ban(0, reason: "Account less than 5 minutes old, possible spam account")
  end
end