# Crystal: Information - Contains commands that display information about certain things, such as a user, the server, etc.

module Bot::Information
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Bot::Models

  SPECIAL_AKNOWLEDGEMENTS = {
    841387928127406120 => "Administrator",
    841434908856811550 => "Bot Manager",
    841388219890663484 => "Moderator",
    841433757403709461 => "Subreddit Moderator",
    841511276160876574 => "Retired Staff"
  }
  
  command :userinfo, aliases: [:info], min_args: 1 do |event, user_id|
    Bot::COMMAND_LOGGER.log(event, user_id)

    break unless event.user.has_permission?(:mod)

    if !(member = Bot::BOT.user(user_id)&.on(event.server.id))
      event.send_embed{ |e| e.color = "#e12a2a"; e.title = "❌ User could not be found on this server." }
      break
    end

    author_name = member.distinct
    avatar_url = member.avatar_url
    username = member.name
    nickname = member.nick.nil? ? "None" : member.nick
    is_bot = member.bot_account?

    if member.activities.custom_status.empty?
      status = "None"
    else
      custom_activity = member.activities.custom_status[0]
      emoji = custom_activity.emoji.nil? ? "" : custom_activity.emoji.mention + " "
      state = custom_activity.state.nil? ? "" : custom_activity.state

      status = emoji + state
    end

    presence = member.status.capitalize
    is_boosting = member.boosting?
    time_created = "<t:#{member.creation_time.to_i}:f>"
    joined_server = "<t:#{member.joined_at.to_i}:f>"
    mute_reason = Mute[member.id]&.reason

    everyone_role_id = event.server.everyone_role.id
    roles_without_everyone = member.roles.sort_by{ |r| r.position }.reverse - [everyone_role_id]
    roles = roles_without_everyone.empty? ? "None" : roles_without_everyone.map(&:mention).join(" ")

    special_acknowledgements = []
    special_acknowledgements << "Owner" if member.owner? 
    SPECIAL_AKNOWLEDGEMENTS.each{ |role_id, title| special_acknowledgements << title if member.role?(role_id) } 

    event.send_embed do |e|
      e.color = "#346beb"
      e.author = { name: author_name, icon_url: avatar_url }
      e.thumbnail = { url: avatar_url }
      e.description = "[Profile Picture](#{avatar_url}?size=1024)"
      e.footer = { text: "User ID: #{member.id}" }
      e.timestamp = Time.now

      e.add_field(name: "Roles", value: roles)
      e.add_field(name: "Username", value: username, inline: true)
      e.add_field(name: "Nickname", value: nickname, inline: true)
      e.add_field(name: "Bot?", value: is_bot, inline: true)
      e.add_field(name: "Presence", value: presence, inline: true)
      e.add_field(name: "Status", value: status, inline: true)
      e.add_field(name: "Boosting?", value: is_boosting, inline: true)
      e.add_field(name: "Created Account On", value: time_created, inline: true)
      e.add_field(name: "Joined Server On", value: joined_server, inline: true)
      e.add_field(name: "Mute Reason", value: mute_reason) if mute_reason

      if !special_acknowledgements.empty?
        e.add_field(name: "Special Acknowledgements", value: special_acknowledgements.join(", "))
      end
    end
  end
end