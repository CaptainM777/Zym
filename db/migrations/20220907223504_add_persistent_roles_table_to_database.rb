# Migration: AddPersistentRolesTableToDatabase
Sequel.migration do
  change do
    create_table(:persistent_roles) do
      primary_key :id
    end
  end
end