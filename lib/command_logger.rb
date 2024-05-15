class CommandLogger
  include Constants

  def initialize(bot)
    @bot = bot
  end

  def log(command_event, args="Isn't required.")
    puts <<~COMMAND_INFO
    ---------------------------------------
    Command usage detected. Information:
    Command name: #{command_event.command.name}
    Command arguments: #{args}
    Command invoker: #{command_event.author.distinct} (#{command_event.author.id})
    Channel: #{command_event.channel.name} (#{command_event.channel.id})
    Timestamp: #{command_event.message.timestamp}
    ---------------------------------------
    COMMAND_INFO
  end
end