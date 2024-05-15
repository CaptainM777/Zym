# Crystal: StatCommands::UserCommands

module Bot::Fun::StatCommands::UserCommands
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Bot::Models
  include Constants

  current_buckets = ["hugs", "jellytarts"]
  current_buckets.each do |bucket_name|
    next if Bucket[bucket_name]
    Bucket.create(name: bucket_name, limit: 1, time_span: 30)
  end

  hug_bucket = Discordrb::Commands::Bucket.new(Bucket["hugs"].limit, Bucket["hugs"].time_span, nil)
  jellytart_bucket = Discordrb::Commands::Bucket.new(Bucket["jellytarts"].limit, Bucket["jellytarts"].time_span, nil)

  def self.rate_limit(time, channel)
    channel.send_temporary_message("**Please wait #{time_string(time)} before using this command again**", 5)
  end

  command :hug do |event, *user|
    break unless (recepient = SERVER.get_user(user.join(" "))) && event.user != recepient

    if (time = hug_bucket.rate_limited?(event.user.id))
      rate_limit(time, event.channel)
      break
    end

    giving_hug_user = HugUser[event.user.id] || HugUser.create(id: event.user.id)
    receiving_hug_user = HugUser[recepient.id] || HugUser.create(id: recepient.id)

    giving_hug_user.given += 1
    receiving_hug_user.received += 1

    giving_hug_user.save
    receiving_hug_user.save

    event.respond(
      "<:BigHug:843544624969940992> | **#{event.user.name}** *gives* #{recepient.mention} *a warm hug.*",
      false, # tts
      {
          author: {
              name: "#{giving_hug_user.given} hugs given | #{giving_hug_user.received} hugs received",
              icon_url: event.user.avatar_url
          },
          color: 0xFFD700
      }
    )
  end

  command :jellytart, aliases: [:tart] do |event, *user|
    break unless (recepient = SERVER.get_user(user.join(" "))) && event.user != recepient

    if (time = jellytart_bucket.rate_limited?(event.user.id))
      rate_limit(time, event.channel)
      break
    end

    giving_jellytart_user = JellytartUser[event.user.id] || JellytartUser.create(id: event.user.id)
    receiving_jellytart_user = JellytartUser[recepient.id] || JellytartUser.create(id: recepient.id)

    giving_jellytart_user.given += 1
    receiving_jellytart_user.received += 1

    giving_jellytart_user.save
    receiving_jellytart_user.save

    event.respond(
      "<:EzranJelly:843573828764696587> | **#{event.user.name}** *gives* #{recepient.mention} *a jelly tart!*",
      false, # tts
      {
          author: {
              name: "#{giving_jellytart_user.given} jellytarts given | #{giving_jellytart_user.received} jellytarts received",
              icon_url: event.user.avatar_url
          },
          color: 0xFFD700
      }
    )
  end
end