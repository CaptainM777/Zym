# Crystal: JoinLeaveLogs

module Bot::JoinLeaveLogs
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Bot::Models
  include Constants

  invites = []

  ready do |event|
    sleep 1
    server = event.bot.server(SERVER_ID)
    invites += server.invites
  end

  invite_create{ |event| invites << event.invite }
  
  member_join do |event|
    new_invites_list = event.server.invites
    invite_used = new_invites_list.select do |new_invite|
      old_invite = invites.select{ |old_invite| new_invite.code == old_invite.code }[0]
      old_invite.uses != new_invite.uses
    end[0]

    invites = new_invites_list

    join_webhook = event.bot.channel(ENV['JOIN_LEAVE_LOG_ID']).webhooks[0]
    join_webhook.execute do |builder|
      builder.add_embed do |e|
        e.color = "#6df67e"
        e.author = { name: event.user.distinct, icon_url: event.user.avatar_url }
        e.title = "Member Joined"
        e.add_field(name: "Account Created", value: "<t:#{event.user.creation_time.to_i}:R> on <t:#{event.user.creation_time.to_i}:f>")
        e.add_field(
          name: "Invite Used", 
          value: invite_used.nil? ? "Unknown" : "#{invite_used.code} created by #{invite_used.user.mention} (#{invite_used.user.distinct})"
        )
        e.image = Discordrb::Webhooks::EmbedImage.new(url: "#{event.user.avatar_url}?size=1024")
        e.footer = { text: "User ID: #{event.user.id}" }
        e.timestamp = Time.now
      end
    end
  end

  member_leave do |event|
    leave_webhook = event.bot.channel(ENV['JOIN_LEAVE_LOG_ID']).webhooks[1]
    leave_webhook.execute do |builder|
      builder.add_embed do |e|
        e.color = "#e12a2a"
        e.author = { name: event.user.distinct, icon_url: event.user.avatar_url }
        e.title = "Member Left"
        e.add_field(name: "Account Created", value: "<t:#{event.user.creation_time.to_i}:R> on <t:#{event.user.creation_time.to_i}:f>")
        e.image = Discordrb::Webhooks::EmbedImage.new(url: "#{event.user.avatar_url}?size=1024")
        e.footer = { text: "User ID: #{event.user.id}" }
        e.timestamp = Time.now
      end
    end
  end
end