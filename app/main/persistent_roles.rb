# Crystal: PersistentRoles

module Bot::PersistentRoles
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Bot::Models
  include Constants

  def self.handle_multi_word_roles(roles)
    roles = roles.join(" ")
    multi_word_roles = roles.scan(/"([^"]*)"/).flatten
    single_word_roles = roles.gsub(/"([^"]*)"/, "").split(" ")

    (multi_word_roles + single_word_roles).uniq
  end

  def self.check_user_roles_against_db_roles(member)
    user_roles = member.roles.select{ |r| PersistentRole[r.id] }.map(&:id)
    pr_user = PrUser[member.id]

    if user_roles.empty?
      pr_user.destroy if pr_user
      return 
    end
    
    if !pr_user
      pr_user = PrUser.create(id: member.id)
      user_roles.each{ |rid| pr_user.add_pr_user_role(id: "#{member.id}_#{rid}") }
    else
      db_roles = pr_user.get_role_ids

      roles_to_add_to_db = user_roles - db_roles
      roles_to_remove_from_db = db_roles - user_roles

      roles_to_add_to_db.each{ |rid| pr_user.add_pr_user_role(PrUserRole.new(id: "#{member.id}_#{rid}")) }
      roles_to_remove_from_db.each{ |rid| PrUserRole["#{member.id}_#{rid}"].destroy }
    end
  end

  ready do |event|
    sleep 0.5
    server = event.bot.server(SERVER_ID)
    non_bot_users = server.members.select{ |m| !m.bot_account? }
    non_bot_users.each{ |m| check_user_roles_against_db_roles(m) }
  end

  member_update{ |event| check_user_roles_against_db_roles(event.user) }

  member_join do |event|
    pr_user = PrUser[event.user.id]

    if pr_user
      db_roles = pr_user.get_role_ids
      server_roles = pr_user.get_role_ids.map{ |rid| event.server.role(rid) }
      server_roles.each{ |r| event.user.add_role(r) }
    end
  end
  
  command :addpersistentroles, min_args: 1, aliases: [:addpr] do |event, *roles|
    Bot::COMMAND_LOGGER.log(event, roles)

    break unless event.user.has_permission?(:mod)

    roles = handle_multi_word_roles(roles.map(&:downcase))
    server_roles = roles.map{ |r| event.bot.role(r) }.compact

    if server_roles.empty?
      event.send_embed{ |e| e.color = "#e12a2a"; e.description = "❌ None of the roles you provided exist on the server." }
      break
    end

    # Checks if any of the roles are managed or above Zym's highest role

    managed_roles = server_roles.select{ |r| r.managed? }

    zym_highest_role_position = event.bot.member(event.server.id, event.bot.profile.id).highest_role.position
    roles_above_highest_role = server_roles.select{ |r| r.position >= zym_highest_role_position }

    if !managed_roles.empty? || !roles_above_highest_role.empty?
      event.send_embed do |e| 
        e.color = "#e12a2a" 
        e.description = "❌ Your role(s) couldn't be added because one or more of them are either unassignable or above Zym's highest role."
      end
      break
    end

    server_roles.each{ |r| PersistentRole.create(id: r.id) if !PersistentRole[r.id] }

    event.send_embed{ |e| e.color = "#6df67e"; e.description = "✅ Roles successfully added!" }
  end

  command :removepersistentroles, min_args: 1, aliases: [:removepr, :deletepr] do |event, *roles|
    Bot::COMMAND_LOGGER.log(event, roles)

    break unless event.user.has_permission?(:mod)

    roles = handle_multi_word_roles(roles.map(&:downcase))
    server_roles = roles.map{ |r| event.bot.role(r) }.compact

    if server_roles.empty?
      event.send_embed{ |e| e.color = "#e12a2a"; e.description = "❌ None of the roles you provided exist on the server." }
      break
    end

    roles_in_db = server_roles.select{ |r| PersistentRole[r.id] }

    if roles_in_db.empty?
      event.send_embed{ |e| e.color = "#e12a2a"; e.description = "❌ None of the roles you provided are in the database." }
      break
    end

    roles_in_db.each{ |r| PersistentRole[r.id].delete }

    event.send_embed{ |e| e.color = "#6df67e"; e.description = "✅ Roles successfully deleted!" }
  end

  command :showpersistentroles, aliases: [:showpr, :listpr, :prlist] do |event, arg|
    Bot::COMMAND_LOGGER.log(event)

    if arg == "master"
      embed_title = "Master list of roles that will be added back if you leave and come back to the server:"
      roles = PersistentRole.all.map{ |r| event.bot.role(r.id) }.compact
      embed_description = roles.empty? ? "None" : roles.map(&:mention).join("\n")
    else
      embed_title = "Roles you have that will be added back if you leave and come back to the server:"
      roles = event.user.roles.select{ |r| PersistentRole[r.id] }
      embed_description = roles.empty? ? "None" : roles.map(&:mention).join("\n")
    end

    event.send_embed do |embed|
      embed.color = 0xFFD700
      embed.author = {
        name: "Persistent Roles",
        icon_url: event.server.icon_url
      }
      embed.title = embed_title
      embed.description = embed_description
    end
  end

  command :clearpersistentroles, aliases: [:clearpr, :prclear] do |event|
    Bot::COMMAND_LOGGER.log(event)

    break unless event.user.has_permission?(:cap)

    PersistentRole.dataset.delete

    event.send_embed{ |e| e.color = "#6df67e"; e.description = "✅ Persistent roles list successfully cleared!" }
  end
end