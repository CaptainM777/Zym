# Migration: MostRecentModMessage
Sequel.migration do
  up do
    create_table(:most_recent_mod_message) do
      Integer :message_id
      String :message_content
      Integer :channel_id
      Integer :user_id
      Time :timestamp
    end

    # Inserts a record upon running the migration so I don't have to check to see if the table is empty
    from(:most_recent_mod_message).insert(nil, nil, nil, nil, nil)
  end

  down do
    drop_table(:most_recent_mod_message)
  end
end