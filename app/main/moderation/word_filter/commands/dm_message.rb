require_relative '../utilities.rb'

module Bot::Moderation::WordFilter::Commands::DmMessage
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  extend Bot::Moderation::WordFilter::Utilities
  include Constants

  @@event = nil

  module_function

  def set_event(event)
    @@event = event
  end

  def set(message)
    if message.empty?
      @@event << "**Your command has no message argument!**"
      return
    end   
    DB[:word_filter_message].update(message: message.join(" "))
    @@event.respond "The message to be DM'd upon deletion has been set to: `#{message.join(" ")}`"
  end 

  def get
    @@event.respond "The message to be DM'd upon deletion is set to: " +
    "`#{DB[:word_filter_message].get(:message)}`"
  end

  def reset
    DB[:word_filter_message].update(message: "Your message has been deleted because it contained a banned word.")
    @@event.respond "The message to be DM'd upon deletion has been reset to its default value: " +
    "`Your message has been deleted because it contained a banned word.`"
  end
end