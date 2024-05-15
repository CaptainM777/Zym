# Migration: CamsChannelsBlacklist
Sequel.migration do
  change do
    create_table(:cams_channels_blacklist) do
      Integer :id, primary_key: true
    end
  end
end