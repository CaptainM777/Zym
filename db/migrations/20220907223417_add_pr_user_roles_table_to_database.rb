# Migration: AddPrUserRolesTableToDatabase
Sequel.migration do
  change do
    create_table(:pr_user_roles) do
      String :id, primary_key: true
      foreign_key :pr_user_id, :pr_users
    end
  end
end