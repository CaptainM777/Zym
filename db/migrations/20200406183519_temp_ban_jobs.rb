# Migration: TempBanJobs
Sequel.migration do
  up do
    # Put a database migration here.
    # For details on Sequel migrations, visit https://github.com/jeremyevans/sequel/blob/master/doc/migration.rdoc
    create_table(:temp_ban_jobs) do
      Integer :user_id, primary_key: true
      String :user 
      Time :job_end
    end
  end

  down do
    # Put a reversal of the above migration here, to be executed on a migration rollback.
    # For details on Sequel migrations, visit https://github.com/jeremyevans/sequel/blob/master/doc/migration.rdoc
    drop_table(:temp_ban_jobs)
  end
end