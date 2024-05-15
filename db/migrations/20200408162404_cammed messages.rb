# Migration: Cammed Messages
Sequel.migration do
  up do
    # Put a database migration here.
    # For details on Sequel migrations, visit https://github.com/jeremyevans/sequel/blob/master/doc/migration.rdoc
    create_table(:cammed_messages) do
      Integer :message_id, primary_key: true
      Integer :message_author_id
      String :message_author
      Time :timestamp
    end
  end

  down do
    # Put a reversal of the above migration here, to be executed on a migration rollback.
    # For details on Sequel migrations, visit https://github.com/jeremyevans/sequel/blob/master/doc/migration.rdoc
    drop_table(:cammed_messages)
  end
end