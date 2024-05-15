# Crystal: BotOperations
module Bot::BotOperations
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Bot::Models
  include Constants

  command :restart, aliases: [:r] do |event|
    Bot::COMMAND_LOGGER.log(event)
    break if !event.user.has_permission?(:mod)
    event.send_embed{ |embed| embed.description = "✅ Restarting bot"; embed.color = "#6df67e" }
    Bot::BOT.stop
  end

  command :stop, aliases: [:st] do |event|
    break if !event.user.has_permission?(:cap)
    event.send_embed{ |embed| embed.description = "✅ Stopping bot"; embed.color = "#6df67e" }
    Bot::BOT.stop
    exit(2)
  end
end