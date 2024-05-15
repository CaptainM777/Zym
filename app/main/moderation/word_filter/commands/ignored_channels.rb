require_relative '../utilities.rb'

module Bot::Moderation::WordFilter::Commands::IgnoredChannels
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  extend Bot::Moderation::WordFilter::Utilities
  include Bot::Moderation::WordFilter::Utilities::Constants
  include Constants

  @@event = nil

  module_function

  def set_event(event)
    @@event = event
  end

  def add(channels)
    channels.map! do |channel|
      begin
        IGNORED_CHANNELS.insert(channel.id)
      rescue Sequel::UniqueConstraintViolation
        @@event << "**#{channel.mention} is already ignored!**"
        nil
      else
        channel.mention
      end
    end

    channels.reject!{ |channel| channel.nil? }

    @@event.respond(
      "#{channels.join(", ")} #{channels.size == 1 ? "has" : "have"} been ignored."
    ) unless channels.empty?
  end

  def remove(channels)
    channels.map! do |channel|
      if IGNORED_CHANNELS.first(channel_id: channel.id)
        IGNORED_CHANNELS.where(channel_id: channel.id).delete
        channel.mention
      else
        @@event << "#{channel.mention} isn't an ignored channel!"
        nil
      end 
    end

    channels.reject!{ |channel| channel.nil? }

    @@event.respond(
      "#{channels.join(", ")} #{channels.size == 1 ? "has" : "have"} been unignored."
    ) unless channels.empty?
  end

  def list
    ignored_channels = IGNORED_CHANNELS.select_map(:channel_id)
                                       .map!{ |id| Bot::BOT.channel(id)&.mention }
                                       .reject{ |c| c.nil? }
    if ignored_channels.empty?
      @@event << "**There are no ignored channels.**"
      return
    end
    @@event.respond "Channels currently ignored: #{ignored_channels.join(", ")}"
  end

  def clear
    prompt = "Are you sure you want to remove all ignored channels? **This is irreversible.** Respond with 'y' for yes or 'n' for no."
    answer = yes_or_no(prompt, @@event)
    if answer == 'y'
      IGNORED_CHANNELS.delete
      @@event.respond "**All the ignored channels have been removed.**"
    else
      @@event.respond "**Cancelled.**"
    end
  end
end