# Migration: WordFilterMessage
Sequel.migration do
  up do
    create_table(:word_filter_message) do
      String :message
    end

    # Inserts a default message when the migration is ran
    from(:word_filter_message).insert("Your message has been deleted because it contained a banned word.")
  end

  down do
    drop_table(:word_filter_message)
  end
end