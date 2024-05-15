# Crystal: UtilityCommands -
module Bot::UtilityCommands
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer

  poll_bucket = Bot::BOT.bucket(:poll, limit: 1, time_span: 60)
  
  command :poll do |event|
    time_remaining = poll_bucket.rate_limited?(event.channel.id)
    if time_remaining && !event.user.has_permission?(:mod)
      event.send_temp("**You can use this command in this channel in #{time_remaining.round} seconds**", 7)
      break
    end

    question = event.message.content.delete_prefix("-poll")
    unless question.empty? # Message only contains '-poll'
      event.message.delete

      message = event.send_embed do |embed|
        embed.author = {
          name: event.user.distinct,
          icon_url: event.user.avatar_url
        }
        embed.description = "#{question}\n\n:one: Yes\n:two: No\n:three: Indifferent"
        embed.color = "#026440"
      end

      message.create_reactions('1️⃣', '2️⃣', '3️⃣')
      nil
    end
  end

  command :snowflake do |event, id|
    if id.to_i == 0
      event.respond "**Invalid ID.**"
      break
    end

    discord_epoch = 1420070400000
    unix_time = ((id.to_i >> 22) + discord_epoch) / 1000

    event.respond "<t:#{unix_time}:f>"
  end

  command :messageprint, aliases: [:msgprint], min_args: 1 do |event, *args|
    break if !event.user.has_permission?(:mod)

    channel = event.bot.get_channel(args.length == 1 ? event.channel.id.to_s : args[0])
    if channel.nil?
      event.send_embed{ |e| e.color = "#e12a2a"; e.title = "❌ Channel not found." }
      break
    end

    message = channel.load_message(args[1] || args[0])
    if message.nil?
      event.send_embed{ |e| e.color = "#e12a2a"; e.title = "❌ Message not found." }
      break
    end

    event.send "```#{message.content}```"
  end

  Bot::BOT.register_application_command(:ping, "Get the bot's ping", server_id: ENV['SERVER_ID'])

  application_command(:ping) do |event|
    ping_message = event.respond(content: "Pinging...", wait: true)
    ping_time = (Time.now - ping_message.timestamp) * 1000
    event.edit_response(content: "Pong! Your ping is `#{ping_time.to_i}ms`")
  end
end