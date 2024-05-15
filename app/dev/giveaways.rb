# Crystal: Giveaways
require 'pstore'

module Bot::Giveaways
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants
  include Bot::Models

  # On startup, reschedules giveaway end tasks or executes giveaway end tasks if those giveaways ended while the bot was down
  ready do
    next if Giveaway.all.empty?

    Giveaway.all.each do |giveaway|
      giveaway_channel = Bot::BOT.channel(giveaway.channel_id)
      giveaway_message = giveaway_channel.load_message(giveaway.id)
      giveaway_manager = GiveawayManager.new(giveaway_message)

      if giveaway.ended # Giveaway ends while the bot is down
        if !giveaway.entrants_stored_for_reroll?
          giveaway_manager.end_giveaway
        end
      else
        giveaway_manager.schedule_giveaway_end
      end
    end
  end

  SCHEDULER.cron '* * * * * UTC' do
    Giveaway.all.each do |giveaway|
      giveaway.destroy if giveaway.ended && giveaway.reroll_period_elapsed
    end
  end

  ENTRANTS = PStore.new("#{ENV['DATA_PATH']}/giveaway_entrants.pstore")

  class GiveawayCreator
    include Constants
    include Bot::Models

    def initialize(channel, host)
      @channel = channel
      @host = host
      @prompt_manager = PromptManager.new(
        channel,
        host,
        timeout: 600, # 5 minutes
        reaction: '❌'
      )
      @responses = {}
    end

    def create_giveaway
      if maximum_giveaways_reached?
        @channel.send "**The maximum number of giveaways (5) has been created! Wait until one of them ends before creating another one.**"
        return
      end

      create_channel_prompt
      return if @responses[:channel].nil? # Command is cancelled

      create_time_prompt
      return if @responses[:time].nil?

      create_winners_prompt
      return if @responses[:num_of_winners].nil?

      create_prize_prompt
      return if @responses[:prize].nil?

      giveaway_message = @responses[:channel].send_embed do |embed|
        embed.description = "A giveaway has been created by #{@host.mention} (#{@host.distinct})!"
        embed.add_field(name: "End Date", value: "<t:#{Time.now.to_i + @responses[:time]}:f>")
        embed.add_field(name: "Number of Winners", value: @responses[:num_of_winners])
        embed.add_field(name: "Prize", value: @responses[:prize])
        embed.add_field(name: "How to Enter Giveaway", value: "Press the '🎉' react to enter the giveaway, and unreact to pull out of the giveaway.")
        embed.color = "#2175e3"
      end

      giveaway_message.react('🎉')

      save_to_db(giveaway_message.id, giveaway_message.timestamp)
      GiveawayManager.new(giveaway_message).schedule_giveaway_end

      "Your giveaway has started in #{@responses[:channel].mention}.\n\n**Do not delete the giveaway message or embed in the aforementioned channel.** Doing so "\
      "will result in no winners being announced. If you want to cancel a giveaway, use `-giveawaycancel` or `-gcancel`. Use `-help giveawaycancel` for more information."
    end

    private

    def maximum_giveaways_reached?
      # TODO: query active giveaways only, not total number of giveaways in the DB
      Giveaway.all.count == 5
    end

    def create_channel_prompt
      channel_prompt = "Let's get started! What channel would you like to host the giveaway in? "\
                       "Press '❌' at any time to cancel the giveaway creation.\n\n`Respond with either a channel ID or a channel mention.`"

      @prompt_manager.create(channel_prompt) do |content|
        giveaway_channel = Bot::BOT.get_channel(content)

        if giveaway_channel.nil?
          @channel.send "**Invalid channel.**" 
          next
        end

        @responses[:channel] = giveaway_channel
        true
      end
    end

    def create_time_prompt
      time_prompt = "Your giveaway will happen in #{@responses[:channel].mention}. How long do you want the giveaway to last?"\
                    "\n\n`Respond with a time format similar to these examples: 200s, 15m, 6h, 10d. "\
                    "'s' stands for seconds, 'm' stands for minutes, 'h' stands for hours, and 'd' stands for days. "\
                    "The shortest time span that will be accepted is 5 minutes and the longest is 365 days.`"

      @prompt_manager.create(time_prompt) do |content|
        length_of_time = parse_time(content)

        if !length_of_time.between?(1,31536000)
          @channel.send "**The length of time has to be between 5 minutes and 365 days!**"
          next
        end

        @responses[:time] = length_of_time
        true
      end
    end

    def create_winners_prompt
      num_of_winners_prompt = "Your giveaway will last **#{time_string(@responses[:time])}**. How many winners do you "\
                              "want to have?\n\n`Enter a number between 1 and 5 (inclusive).`"

      @prompt_manager.create(num_of_winners_prompt) do |content|
        num_of_winners = content.to_i

        if !num_of_winners.between?(1,5)
          @channel.send "**Your number is not between 1 and 5.**"
          next
        end

        @responses[:num_of_winners] = num_of_winners
        true
      end
    end

    def create_prize_prompt
      prize_prompt = "Your giveaway will have **#{@responses[:num_of_winners]} winner(s)**. What will you be giving away?"\
                     "\n\n`Enter your giveaway prize. The giveaway will start after this question.`"

      @prompt_manager.create(prize_prompt){ |content| @responses[:prize] = content }
    end

    def save_to_db(message_id, message_timestamp)
      Giveaway.create(
        id: message_id,
        channel_id: @responses[:channel].id,
        host: @host.id,
        length: @responses[:time],
        end_time: Time.at(message_timestamp.to_i + @responses[:time]),
        num_of_winners: @responses[:num_of_winners],
        prize: @responses[:prize]
      )
    end
  end

  class GiveawayManager
    include Constants
    include Bot::Models

    def initialize(message)
      @message = message
    end

    def schedule_giveaway_end
      end_time = Giveaway[@message.id].end_time
      SCHEDULER.at(end_time) { end_giveaway }
    end

    def end_giveaway
      giveaway = Giveaway[@message.id]

      begin
        # TODO: remove entrant if they are the host or the bot
        giveaway_entrants = @message.reacted_with('🎉', limit: nil) #.delete_if{ |entrant| entrant.id == giveaway.host }
        return if giveaway_entrants.empty?

        winners = giveaway_entrants.sample(giveaway.num_of_winners)
        # Removes the winner from the list of entrants so that re-rolls won't be able to pick the previous winner
        giveaway_entrants.delete_if{ |entrant| winners.include?(entrant) }

        winners_formatted_string = winners.map{ |winner| winner.mention }.join(", ")

        @message.reply!(
          "Congratulations #{winners_formatted_string}! You've won the giveaway for **#{giveaway.prize}**!",
          allowed_mentions: { parse: ["users"] }
        )

        giveaway_finished_embed = convert_giveaway_embed_to_webhooks_embed
        giveaway_finished_embed.title = "Giveaway Ended"
        giveaway_finished_embed.add_field(name: "Winner(s)", value: winners_formatted_string)
        giveaway_finished_embed.color = "#D2171c"
    
        @message.edit('', giveaway_finished_embed)
      rescue Discordrb::Errors::UnknownMessage
        puts "Error: A giveaway message was deleted. Message and giveaway record ID: #{@message.id}"
        return
      end

      # Adds all giveaway entrants to a pstore which will be deleted 2 weeks after the giveaway ends
      giveaway.add_entrants_for_reroll(giveaway_entrants)
    end

    def cancel_giveaway
      begin
        giveaway_canceled_embed = convert_giveaway_embed_to_webhooks_embed
      rescue EmbedNotFoundError
        return "**The giveaway embed has been deleted."
      else
        giveaway_canceled_embed.title = "Giveaway Cancelled"
        giveaway_canceled_embed.color = "#D2171c"

        @message.edit('', giveaway_canceled_embed)

        Giveaway[@message.id].delete
      end
    end

    class EmbedNotFoundError < StandardError; end
    
    private_constant :EmbedNotFoundError

    private

    def convert_giveaway_embed_to_webhooks_embed
      giveaway_embed = @message.embeds[0]
      raise EmbedNotFoundError if giveaway_embed.nil?

      giveaway_embed.fields.pop # Removes the 'How to Enter Giveaway' field from old embed

      webhooks_embed = giveaway_embed.to_postable # Converts 'giveaway_embed' to a Discordrb::Webhooks::Embed object for sending
      webhooks_embed
    end
  end

  active_giveawaycreate_commands = []

  command :clear do |event|
    ENTRANTS.transaction do
      ENTRANTS.roots.each{ |message_id| ENTRANTS.delete(message_id) }
    end
    puts ENTRANTS.inspect
    event.respond "PStore cleared"
  end

  command :show do |event|
    ENTRANTS.transaction(true) do
      ENTRANTS.roots.each do |key|
        event << "Giveaway ID: #{key}\nEntrants: #{ENTRANTS[key].empty? ? "No entrants." : ENTRANTS[key].join(", ")}\n"
      end
    end
    p ENTRANTS
    nil
  end

  command :giveawaycreate, aliases: [:gcreate] do |event|
    break if !event.user.has_permission?(:mod) || active_giveawaycreate_commands.include?(event.channel.id) 

    active_giveawaycreate_commands << event.channel.id

    creation_response = GiveawayCreator.new(event.channel, event.user).create_giveaway

    # Command is cancelled or timed out
    if creation_response.nil?
      active_giveawaycreate_commands.delete(event.channel.id)
      break
    end

    event.respond creation_response

    active_giveawaycreate_commands.delete(event.channel.id)
    nil
  end

  command :cancelgiveaway, aliases: [:gcancel] do |event, message_id|
    break if !event.user.has_permission?(:mod)

    giveaway = Giveaway[message_id.to_i]
    break "**This giveaway doesn't exist!**" if giveaway.nil?
    break "**This giveaway has already ended!**" if giveaway.ended

    giveaway_message = Bot::BOT.channel(giveaway.channel_id).load(message_id)
    break "**The giveaway message was deleted. The giveaway has been cancelled.**" if giveaway_message.nil?

    cancel_response = GiveawayManager.new(giveaway_message).cancel_giveaway
    event.respond cancel_response
  end
end