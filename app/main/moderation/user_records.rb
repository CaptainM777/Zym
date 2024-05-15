# Crystal: UserRecords - Contains all the commands related to the display and management of user records/punishment logs.

module Bot::Moderation::UserRecords
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Bot::Models
  include Interactivity

  def self.get_username(user_id)
    user = Bot::BOT.user(user_id)
    username = user.nil? ? user_id : user.distinct 
    username
  end
  
  command :cases, min_args: 1 do |event, user_id|
    Bot::COMMAND_LOGGER.log(event, user_id)

    break unless event.user.has_permission?(:mod)

    formatted_logs = PunishmentLog.format_logs(user_id)
    user = Bot::BOT.user(user_id)

    # For author embed part
    name = user.nil? ? user_id : user.distinct
    avatar_url = user.nil? ? "https://discordapp.com/assets/dd4dbc0016779df1378e7812eabaa04d.png" : user.avatar_url

    pages = Pages.new(
      formatted_logs,
      event.user.id,
      event.channel.id,
      author: { name: name, icon_url: avatar_url },
      color: "#f7d469",
      title: "Punishment Log", 
      description: "Total: `#{formatted_logs.count}`"
    )

    embed, view = pages.generate_embed_and_pagination_controls

    message = event.send_message('', false, embed, nil, nil, nil, view)

    Interactivity.add_active_page(message.id, pages)

    nil # Prevent implicit return
  end

  command :editcase, min_args: 2 do |event, warn_id, *new_reason|
    Bot::COMMAND_LOGGER.log(event, { warn_id: warn_id, new_reason: new_reason.join(" ") })

    break unless event.user.has_permission?(:mod)
    
    if !(log = PunishmentLog[warn_id.to_i])
      event.send_embed{ |e| e.color = "#e12a2a"; e.title = "❌ Punishment log not found." }
      break
    end

    old_reason = log.reason
    new_reason = new_reason.join(" ")

    log.update(reason: new_reason)

    username = get_username(log.user_id) 

    event.send_embed do |e|
      e.color = "#f7d469"
      e.description = "Edited case `##{log.id}` for user #{username}"
      e.add_field(name: "Before", value: old_reason)
      e.add_field(name: "After", value: new_reason)
    end
  end

  command :deletecase, aliases: [:delcase], min_args: 1 do |event, warn_id|
    Bot::COMMAND_LOGGER.log(event, warn_id)

    break unless event.user.has_permission?(:mod)

    if !(log = PunishmentLog[warn_id.to_i])
      event.send_embed{ |e| e.color = "#e12a2a"; e.title = "❌ Punishment log not found." }
      break
    end

    log_id = log.id

    log.delete

    username = get_username(log.user_id)

    event.send_embed{ |e| e.color = "#f7d469"; e.description = "Deleted case `##{log_id}` for #{username}" }
  end

  command :logcase, min_args: 2 do |event, user_id, *reason|
    Bot::COMMAND_LOGGER.log(event, { user_id: user_id, reason: reason.join(" ") })

    break unless event.user.has_permission?(:mod)

    if !(user = Bot::BOT.user(user_id))
      event.send_embed{ |e| e.color = "#e12a2a"; e.title = "❌ User could not be found." }
      break 
    end

    username = user.distinct

    log = PunishmentLog.create(
      user_id: user.id,
      time: Time.now.to_i,
      responsible_moderator_id: event.user.id,
      type: "Logged Case",
      reason: reason.join(" ")
    )

    event.send_embed do |e|
      e.color = "#f7d469"
      e.description = "⚠️ Logged case `##{log.id}` for `#{username}`"
      e.add_field(name: "Reason", value: reason.join(" "))
    end
  end
end