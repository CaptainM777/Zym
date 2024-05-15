require 'rufus-scheduler'
require 'open3'

# Crystal: CapModule - Commands and other features for my use only.
module Bot::CapModule
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  module_function

  command :eval do |event|
    break if event.user.id != CAP_ID

    begin
      output = eval event.message.content.delete_prefix("-eval")
    rescue StandardError => e
      output = e
    end

    begin
      event.send_embed do |embed|
        embed.color = "#008844"
        embed.title = "Eval Result"
        embed.description = "```ruby\n#{output.nil? ? "No output" : output}```"
      end
    rescue StandardError => e 
      event.send_embed do |embed|
        embed.color = "#e12a2a"
        embed.title = "❌ An error has occurred during posting! See console for more details."
      end

      p e
    end
    
    nil
  end
end