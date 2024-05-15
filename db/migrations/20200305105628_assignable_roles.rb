# Migration: AssignableRoles
Sequel.migration do
  up do
    # Put a database migration here.
    # For details on Sequel migrations, visit https://github.com/jeremyevans/sequel/blob/master/doc/migration.rdoc
    create_table(:assignable_roles) do
      String :role_name, text: true, primary_key: true
      Integer :role_id, unique: true
      String :category, text: true
    end
  end

  down do
    # Put a reversal of the above migration here, to be executed on a migration rollback.
    # For details on Sequel migrations, visit https://github.com/jeremyevans/sequel/blob/master/doc/migration.rdoc
    drop_table(:assignable_roles)
  end
end
