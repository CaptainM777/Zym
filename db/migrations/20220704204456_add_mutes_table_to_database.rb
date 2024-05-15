# Migration: AddMutesTableToDatabase
Sequel.migration do
  change do
    create_table(:mutes) do
      primary_key :id
      String :reason
      Time :start_time
      Time :end_time
    end
  end
end