# Crystal: AssignableRoles - Allows users to assign roles to themselves.
module Bot::AssignableRoles
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  module_function

  ASSIGNABLE_ROLES = DB[:assignable_roles]
  ROLE_ALIASES = DB[:role_aliases]

  MULTIPLE_ROLES_ALLOWED_CATEGORIES = ["no category", "pronouns"]
  
  def retrieve_database_role(name)
    role_query = DB.fetch(%Q(
      SELECT assignable_roles.role_name
      FROM assignable_roles
      LEFT JOIN role_aliases
        ON assignable_roles.role_name = role_aliases.role_name
      WHERE alias = ? or assignable_roles.role_name = ?;
    ), name, name).to_a
      
    role_query.empty? ? (return nil) : (return role_query[0][:role_name])
  end

  def get_category_roles(name)
    role_category = DB.fetch("SELECT category FROM assignable_roles WHERE role_name = ?", name).to_a[0][:category]
    role_array = DB.fetch("SELECT role_name FROM assignable_roles WHERE category = ?", role_category).to_a

    retrieved_roles = Array.new

    if !MULTIPLE_ROLES_ALLOWED_CATEGORIES.include?(role_category)
      role_array.each do |role|
        retrieved_roles << SERVER.get_role(role[:role_name])
      end
    end

    return retrieved_roles
  end
    
  message(start_with: '-') do |event|
    next if retrieve_database_role(event.content.downcase[1..-1]).nil?
    requested_role = event.content.downcase[1..-1]

    server_role = SERVER.get_role(retrieve_database_role(requested_role))

    if(event.user.role?(server_role))
      event.user.remove_role(server_role)
      event << "#{event.user.mention}, your #{server_role.name} role has been removed!"
    else
      category_roles = get_category_roles(retrieve_database_role(requested_role))

      if category_roles.empty?
        event.user.add_role(server_role)
        event << "#{event.user.mention}, you've been given the #{server_role.name} role!"
      else
        event.user.remove_role(category_roles)
        event.user.add_role(server_role)
        event << "#{event.user.mention}, you've been given the #{server_role.name} role!"
      end
    end 
  end

  command :roles, aliases: [:role], min_args: 1, max_args: 1 do |event, *subcommand|
    Bot::COMMAND_LOGGER.log(event, subcommand)

    event_argument = Discordrb::Commands::CommandEvent.new(event.message, event.bot)

    case subcommand[0].downcase
    when "list"
      event.bot.simple_execute("roleslist", event_argument)
    end
  end

  command :roleslist do |event|
    role_categories = ASSIGNABLE_ROLES.map(:category).uniq.map{ |category| category.split(" ").map(&:capitalize).join(" ") }

    event.send_embed do |embed|
      embed.color = 0xFFD700
      embed.author = {
        name: "Self-Assignable Roles",
        icon_url: event.server.icon_url
      }
      embed.description = "These are the roles that you can add to yourself using their respective commands. " +
                          "If the role is in a named category, you can only have one role from that category at a " +
                          "time (except for those under 'Pronouns' and 'No Category')! To remove a role from yourself, simply use its command again."
      role_categories.each do |category|
        embed.add_field(
          name: category.nil? ? "No Category" : category, 
          value: ASSIGNABLE_ROLES.where(category: category.downcase).map([:role_name, :role_id]).map do |role_name, role_id|
                  role_commands = ROLE_ALIASES.where(role_name: role_name).map(:alias).map{ |a| "`-#{a}`" }.unshift("`-#{role_name}`")
                  "• <@&#{role_id}> - #{role_commands.join(", ")}"
                 end.join("\n")
        )
      end
    end
  end
end