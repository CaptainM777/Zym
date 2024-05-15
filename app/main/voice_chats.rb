# Crystal: VoiceChats - Shows a hidden text channel to the user if they join that text channel's corresponding VC.
module Bot::VoiceChats
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  AARY_MUSIC_ID = 904889516630900807

  # Voice => Text
  channels = { 
    841384716095062098 => 841444431882485780, # General
    841443769454428220 => 841444478199005184, # Gaming
    841444272120922162 => 841444738518220851, # Dragon DJ
    841444336184197181 => 841444774421463070 # Streaming
  }
  
  voice_state_update do |event|
    # Skips if the voice state update is a mute/deafen or the user is the aary music bot
    next if event.channel == event.old_channel || event.user.id == AARY_MUSIC_ID

    # User leaves VC or changes VC's
    if !(event.old_channel.nil?)
      old_text_channel = Bot::BOT.channel(channels[event.old_channel.id])
      old_text_channel.delete_overwrite(event.user.id) unless old_text_channel.nil?
    end

    # User changes VC's or just joined VC
    if !(event.channel.nil?)
      text_channel = Bot::BOT.channel(channels[event.channel.id])
      if !(text_channel.nil?)
        text_channel.define_overwrite(event.user, 1024, 0) # Gives read perms for the text channel
        text_channel.send_temporary_message("#{event.user.mention}, you have gained access to <##{text_channel.id}>.", 5)
      end
    end
  end
end