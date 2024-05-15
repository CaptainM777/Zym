# Migration: AddPrUsersTableToDatabase
Sequel.migration do
  change do
    create_table(:pr_users) do
      primary_key :id
    end
  end
end