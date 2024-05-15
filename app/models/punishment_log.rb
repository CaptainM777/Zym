class Bot::Models::PunishmentLog < Sequel::Model
  def self.format_logs(user_id)
    all_logs = where(user_id: user_id).order(:time).all
    all_logs.reverse.map do |log|
      responsible_moderator = Bot::BOT.user(log.responsible_moderator_id)
      length = log.length.nil? ? "" : "\n**Length:** #{time_string(log.length)}"
      days_deleted = log.days_deleted.nil? ? "" : "\n**Days Deleted:** #{log.days_deleted}"
      {
        name: "Case #{log.id} | <t:#{log.time}:f>",
        value: <<~VALUE
        **Responsible Moderator:** #{responsible_moderator.mention} (#{responsible_moderator.distinct})
        **Type:** #{log.type}#{length}#{days_deleted}
        **Reason:** #{log.reason.empty? ? "None given." : log.reason}
        VALUE
      }
    end
  end
end