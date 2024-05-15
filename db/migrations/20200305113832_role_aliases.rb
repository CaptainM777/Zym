# Migration: RoleAliases
Sequel.migration do
  up do
    # Put a database migration here.
    # For details on Sequel migrations, visit https://github.com/jeremyevans/sequel/blob/master/doc/migration.rdoc
    create_table(:role_aliases) do
      String :alias, text: true, primary_key: true
      String :role_name, text: true
      foreign_key [:role_name], :assignable_roles
    end
  end

  down do
    # Put a reversal of the above migration here, to be executed on a migration rollback.
    # For details on Sequel migrations, visit https://github.com/jeremyevans/sequel/blob/master/doc/migration.rdoc
    drop_table(:role_aliases)
  end
end
