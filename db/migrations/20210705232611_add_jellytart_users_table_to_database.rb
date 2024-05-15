# Migration: AddJellytartUsersTableToDatabase
Sequel.migration do
  change do
    create_table(:jellytart_users) do
      primary_key :id
      Integer :given, default: 0
      Integer :received, default: 0
    end
  end
end