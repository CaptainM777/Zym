# Crystal: StatCommands::ModCommands -

module Bot::Fun::StatCommands::ModCommands
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Bot::Models

  BUCKET_NAMES_AND_ALIASES ||= {
    "hugs": ["hug"],
    "jellytarts": ["jellytart", "tarts", "tart"],
  }

  def self.validate_argument(argument)
    BUCKET_NAMES_AND_ALIASES.each do |name, aliases|
      return argument if argument == name.to_s
      return (argument = name.to_s) if aliases.include?(argument)
    end
    false
  end

  def self.limit_timespan_prompt(event)
    limit, time_span = nil
    loop do
      # The heredoc removes newlines present in the string so that the prompt is, essentially, one big line of text
      prompt = event.respond <<~PROMPT.gsub(/^[\s\t]*/, '').gsub(/[\s\t]*\n/, ' ').strip
      Would you like to change the **limit** or the **time span**? The **limit** is the number of times a command 
      can be used within a certain time frame, and the **time span** is that time frame. Respond with `l` for the limit, 
      `ts` for the time span, `c` to cancel.
      PROMPT

      response = event.user.await!.content

      case response
      when 'l'
        event.respond "Enter the new limit."
        limit = event.user.await!.content.to_i
        if limit <= 0
          event.respond "**The limit has to be greater than 0!**" 
          next
        end
        prompt.delete
        break
      when 'ts'
        event.respond <<~PROMPT
        Enter the new time span. The time span has to be formatted a certain way; here are some examples: 
        `40s` (40 seconds), `1m30s` (1 minute and 30 seconds), `3h20m` (3 hours and 20 minutes).
        PROMPT
        time_span = parse_time(event.user.await!.content)
        if time_span < 5
          event.respond "**The time span has to be greater than 5 seconds!**"
          next
        end
        prompt.delete
        break
      when 'c'
        event.respond "**Cancelled.**"
        prompt.delete
        break
      else
        event.respond "**Invalid response. Try again.**"
      end
    end
    return limit, time_span
  end

  command :changesettings, aliases: [:changesetting, :cs],
          min_args: 1, max_args: 1 do |event, *bucket_name|
    break unless event.user.has_permission?(:mod) && (bucket_name = validate_argument(bucket_name[0]))

    bucket = Bucket[bucket_name]
    limit, time_span = limit_timespan_prompt(event)
    break if limit.nil? && time_span.nil?

    if !limit.nil?
      bucket.limit = limit
      event << "**The limit has been changed to #{limit}.**"
    else
      bucket.time_span = time_span
      event << "**The time span has been changed to #{time_string(time_span)}.**"
    end
    bucket.save
    nil
  end

  command :getsettings, aliases: [:getsetting, :gs], 
          min_args: 1, max_args: 1 do |event, *bucket_name|
    break unless event.user.has_permission?(:mod) && (bucket_name = validate_argument(bucket_name[0]))

    bucket = Bucket[bucket_name]
    limit = bucket.limit
    time_span = time_string(bucket.time_span)
    command_name = bucket_name[0..-2]

    event.send_embed do |embed|
      embed.title =  "Current Settings for the #{command_name.capitalize} Command"
      embed.description = <<~SETTINGS
      Users can use the #{command_name} command **#{limit} times** in **#{time_span}**.
      **Limit:** #{limit}
      **Time Span:** #{time_span}
      SETTINGS
      embed.color = 14992397
    end
  end

  command :resetsettings, aliases: [:resetsetting, :reset, :rs],
          min_args: 1, max_args: 1 do |event, *bucket_name|
    break unless event.user.has_permission?(:mod) && (bucket_name = validate_argument(bucket_name[0]))

    bucket = Bucket[bucket_name]
    bucket.limit = 1
    bucket.time_span = 30
    bucket.save
    event << "**The limit has been reset to 1 and the time span has been reset to 30 seconds.**"
  end
end