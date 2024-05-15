# Migration: Buckets
Sequel.migration do
  change do
    # Put a reversible database migration here.
    # For details on Sequel migrations, visit https://github.com/jeremyevans/sequel/blob/master/doc/migration.rdoc
    create_table(:buckets) do
      String :name, primary_key: true
      Integer :limit, null: false
      Integer :time_span, null: false
    end
  end
end