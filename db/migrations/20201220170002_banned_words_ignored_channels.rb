# Migration: Banned-words-ignored-channels
Sequel.migration do
  change do
    create_table(:banned_words_ignored_channels) do
      Integer :channel_id, null: false, unique: true
    end
  end
end