# Crystal: Fun - Contains features that are meant for fun and entertainment.
module Bot::Fun::FunMain
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  zym_emotes = []

  mention do |event|
    next unless event.channel == event.bot.channel(ENV['BOT_CHANNEL_ID'])

    zym_emotes = SERVER.get_zym_emotes if zym_emotes.empty?

    random_index = rand(0..zym_emotes.length-1)
    event.respond "#{zym_emotes[random_index]}"
  end

  command :say, aliases: [:s], min_args: 1, usage: "-say [channel] [message]" do |event, *args|
    Bot::COMMAND_LOGGER.log(event, args)
    
    channel = SERVER.get_channel(args[0])
    break if channel.nil? || !(event.user.has_permission?(:mod))

    message_content = args[1..-1].join(" ")
    channel.send_file(event.message.convert_attachment, caption: message_content)
  end
end
