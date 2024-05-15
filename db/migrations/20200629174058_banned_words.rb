# Migration: BannedWords
Sequel.migration do
  change do
    # Put a reversible database migration here.
    # For details on Sequel migrations, visit https://github.com/jeremyevans/sequel/blob/master/doc/migration.rdoc
    create_table(:banned_words) do
      String :word, null: false, unique: true
    end
  end
end