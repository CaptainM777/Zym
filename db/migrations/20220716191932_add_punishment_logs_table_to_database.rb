# Migration: AddPunishmentLogsTableToDatabase
Sequel.migration do
  change do
    create_table(:punishment_logs) do
      primary_key :id
      Integer :user_id
      Integer :time, null: false # Unix time
      Integer :responsible_moderator_id, null: false
      String :type, null: false
      Integer :length # Seconds; only used for mutes and temporary bans
      Integer :days_deleted # Only used for permanent and temporary bans
      String :reason, null: false
    end
  end
end