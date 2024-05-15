# Crystal: Communication - Allows communication between the DP server mods and I without rejoining the server.
module Bot::Communication
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  def self.send_message(event, message)
    return unless event.user.has_permission?(:mod) || event.user.id == CAP_ID
    message_to_be_sent = "**#{event.user.distinct}:** " +
    "#{message.strip}\n#{event.message.attachments.map!(&:url).join("\n")}"

    latest_mod_message_id = DB[:most_recent_mod_message].get(:channel_id)

    if event.user.id == CAP_ID
      recipient_channel = event.bot.channel(ENV['MOD_CHAT_ID'])
      if latest_mod_message_id && Bot::BOT.channel(latest_mod_message_id)
        recipient_channel = Bot::BOT.channel(latest_mod_message_id)
      end 

      begin 
        sent_message = recipient_channel.send(message_to_be_sent)
      rescue => e 
        event.respond "**An error occurred. Your message wasn't sent to the DP server. See your logs for details.**"
        puts "An error occurred while sending a message to the DP server. Error message: #{e}"
      end
    else
      begin
        mod_message = Bot::BOT.user(CAP_ID).dm(message_to_be_sent)
      rescue => e
        event.respond "**An error occurred. Your message wasn't sent to Cap.**"
        puts "An error occurred while sending a message to you. Error message: #{e}"
      else
        DB[:most_recent_mod_message].update(
          message_id: mod_message.id, 
          message_content: mod_message.content, 
          channel_id: event.channel.id, 
          user_id: event.user.id, 
          timestamp: mod_message.timestamp
        )
        nil
      end
    end
  end

  command :cap do |event|
    Bot::COMMAND_LOGGER.log(event)
    send_message(event, event.message.content.split(" ")[1..-1].join(" "))
  end
end