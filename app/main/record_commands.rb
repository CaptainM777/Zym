# Crystal: RecordCommands - Contains commands that allow me to mass-insert roles and aliases in the 'assignable_roles' table.
module Bot::RecordCommands
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  module_function

  def check_table(table)
    if table.to_a.empty?
      return "Error adding roles to table."
    else
      return "All role records added."
    end
  end
  
  command :insertallroles do |event|
    break unless event.user.id == CAP_ID 

    DB.run(
      <<~INSERT_ROLES
      INSERT INTO assignable_roles VALUES
      ("sky", 841515809641988116, "primal sources"),
      ("ocean", 841515883209162794, "primal sources"),
      ("stars", 841515915371872317, "primal sources"),
      ("earth", 841515931284406333, "primal sources"),
      ("sun", 841515932316467250, "primal sources"),
      ("moon", 841515933520232468, "primal sources"),
      ("dark", 841516087123509249, "primal sources"),
      ("he/him", 842129549713866763, "pronouns"),
      ("she/her", 842129559297327114, "pronouns"),
      ("they/them", 842129561729761300, "pronouns"),
      ("any pronouns", 842129563940290581, "pronouns"),
      ("north america", 842130536244051969, "regions"),
      ("south america", 842130544515088494, "regions"),
      ("europe", 842130553355632691, "regions"),
      ("asia/pacific", 842130556744499270, "regions"),
      ("australia", 842130559860736031, "regions"),
      ("africa", 842130563984785408, "regions"),
      ("watching", 841489377171210270, "no category"),
      ("stream", 842187483512832031, "no category"),
      ("serious", 841440048284172289, "no category");
      INSERT_ROLES
    )

    event.respond check_table(DB[:assignable_roles])
  end

  command :insertallaliases do |event|
    break unless event.user.id == CAP_ID

    DB.run(
      <<~INSERT_ALIASES
      INSERT INTO role_aliases VALUES
      ("he", "he/him"),
      ("him", "he/him"),
      ("she", "she/her"),
      ("her", "she/her"),
      ("they", "they/them"),
      ("them", "they/them"),
      ("any", "any pronouns"),
      ("northamerica", "north america"),
      ("na", "north america"),
      ("southamerica", "south america"),
      ("sa", "south america"),
      ("europe", "europe"),
      ("ea", "europe"),
      ("asia", "asia/pacific"),
      ("pacific", "asia/pacific"),
      ("au", "australia"),
      ("af", "africa");
      INSERT_ALIASES
    )

    event.respond check_table(DB[:role_aliases])
  end
end