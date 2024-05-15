# Migration: StaffInformation
Sequel.migration do
  up do
    # Put a database migration here.
    # For details on Sequel migrations, visit https://github.com/jeremyevans/sequel/blob/master/doc/migration.rdoc
    create_table(:staff_information) do
      Integer :user_id, primary_key: true
      String :username
      String :distinct
      String :avatar_url
      Integer :embed_id
    end
  end

  down do
    # Put a reversal of the above migration here, to be executed on a migration rollback.
    # For details on Sequel migrations, visit https://github.com/jeremyevans/sequel/blob/master/doc/migration.rdoc
    drop_table(:staff_information)
  end
end