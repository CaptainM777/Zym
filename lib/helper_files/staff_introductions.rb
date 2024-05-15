# Crystal: StaffIntroductionsConstants

module StaffIntroductions
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  STAFF_INFORMATION = DB[:staff_information]

  # A hash that links staff members to their intros. Format: user ID => message ID
  MOD_AND_INTRO_IDS ||= {
    admins: {
      # Lys
      575114958325547029 => 708104502645096491,
      # Rei
      203772088111202304 => 705067838309793942,
      # Frank
      229728473688571904 => 704378424197775421
    },
    mods: {
      # Solace
      330583387024785410 => 704574184659091466,
      # Muginn
      162156241739579392 => 704563326096506941,
      # Astral
      262397479348207616 => 704346608103588032,
      # Seer 
      348256966805684225 => 704361020008693828,
      # ODST
      260221077563768844 => 704435713080557638
    }
  }

  # Same as 'MOD_AND_INTRO_IDS', except this hash maps 'User' objects to 'Message' objects
  STAFF_INTROS ||= {
    admins: {},
    mods: {}
  }
end