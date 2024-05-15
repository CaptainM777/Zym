module Constants
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer

  require 'rufus-scheduler'

  # My User ID
  CAP_ID = 260600155630338048

  DB = Bot::DB

  # Miscellaneous
  ZYM_EMOTE_IDS = [679372639038603276, 679372650619076671, 679372660198735874, 679372675189178400,
  679372769183399957, 679372783381381121, 679372800149946384, 679372815564013589]

  # Rufus Scheduler constant
  SCHEDULER = Rufus::Scheduler.new

  settings = JSON.parse(ENV['SERVER_SETTINGS'])
  channel_ids = settings["channel_ids"]
  role_ids = settings["role_ids"]

  ENV['AUTOMOD_LOG_ID'] = channel_ids["automod_log_id"]

  Bot::BOT.ready do
    settings = JSON.parse(ENV['SERVER_SETTINGS'])
    role_ids = settings["role_ids"]

    SERVER ||= Bot::BOT.servers[settings["server_id"]]

    # ID constants used in other parts of the bot
    SERVER_ID ||= settings["server_id"]
    ENV['SERVER_ID'] = settings["server_id"].to_s

    # Roles
    ROLES ||= SERVER.roles
    ROLE_NAMES ||= ROLES.map{ |r| r.name.downcase }
    ADMIN_ROLE ||= ROLES.find{ |r| r.id == role_ids["admin_role_id"] }
    ENV['MOD_ROLE_ID'] = role_ids["mod_role_id"]
    ENV['MUTED_ROLE_ID'] = role_ids["muted_role_id"]
    ENV['BIRTHDAY_ROLE_ID'] = role_ids["birthday_role_id"]

    # Channels
    ENV['MOD_LOG_ID'] = channel_ids["mod_log_id"]
    ENV['STORYBOOK_ID'] = channel_ids["storybook_id"]
    ENV['BIRTHDAY_CHANNEL_ID'] = channel_ids["birthday_channel_id"]
    ENV['MOD_CHAT_ID'] = channel_ids["mod_chat_id"]
    ENV['JOIN_LEAVE_LOG_ID'] = channel_ids["join_leave_log_id"]

    if(settings["server"] == "dragon prince")
      ENV['CAP_PLAYGROUND_ID'] = channel_ids["cap_playground_id"]
      ENV['BOT_CHANNEL_ID'] = channel_ids["bot_channel_id"]
    end
  end
end