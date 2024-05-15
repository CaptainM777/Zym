# Migration: AddTempBansTableToDatabase
Sequel.migration do
  up do
    create_table(:temp_bans) do
      primary_key :id
      Time :end_time
    end
  end

  down do
    drop_table?(:temp_ban_jobs)
    drop_table(:temp_bans)
  end
end