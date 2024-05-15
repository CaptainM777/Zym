# This file contains the schema for the database.
# Under most circumstances, you shouldn't need to run this file directly.
require 'sequel'

module Schema
  Sequel.sqlite(ENV['DB_PATH']) do |db|
    db.create_table?(:assignable_roles, :ignore_index_errors=>true) do
      String :role_name, :text=>true, :null=>false
      Integer :role_id
      String :category, :text=>true
      
      primary_key [:role_name]
      
      index [:role_id], :name=>:sqlite_autoindex_assignable_roles_2, :unique=>true
    end

    db.create_table?(:role_aliases) do
      String :alias, :text=>true, :null=>false
      foreign_key :role_name, :assignable_roles, :type=>String, :text=>true
      
      primary_key [:alias]
    end

    db.create_table?(:birthdays) do
      primary_key :user_id
      String :user, :size=>255
      Date :birthday
      TrueClass :announcement
    end

    db.create_table?(:temp_ban_jobs) do
      primary_key :user_id
      String :user, :size=>255
      DateTime :job_end
    end

    db.create_table?(:cammed_messages) do
      primary_key :message_id
      Integer :message_author_id
      String :message_author, :size=>255
      DateTime :timestamp
    end

    db.create_table?(:cam_requirement) do
      Integer :num_of_cams
    end

    db.create_table?(:staff_information) do
      primary_key :user_id
      String :username, :size=>255
      String :distinct, :size=>255
      String :avatar_url, :size=>255
      Integer :embed_id
    end

    db.create_table?(:mutes) do
      primary_key :user_id
      String :distinct, :size=>255, :null=>false
      String :reason, :size=>255
      Integer :mute_length, :null=>false
      Float :time_left, :null=>false
      DateTime :mute_start, :null=>false
    end

    db.create_table?(:buckets) do
      String :name, :size=>255, :null=>false
      Integer :limit, :null=>false
      Integer :time_span, :default=>5, :null=>false
      
      primary_key [:name]
    end

    db.create_table?(:stats) do
      primary_key :user_id
      Integer :received, :default=>0
      Integer :given, :default=>0
    end

    db.create_table?(:banned_words, :ignore_index_errors=>true) do
      String :word, :size=>255, :null=>false
      
      index [:word], :name=>:sqlite_autoindex_banned_words_1, :unique=>true
    end

    db.create_table?(:word_filter_message) do
      String :message, :size=>255
    end

    db.create_table?(:most_recent_mod_message) do
      Integer :message_id
      String :message_content, :size=>255
      Integer :channel_id
      Integer :user_id
      DateTime :timestamp
    end

    db.create_table?(:banned_words_ignored_channels, :ignore_index_errors=>true) do
      Integer :channel_id, :null=>false
      
      index [:channel_id], :name=>:sqlite_autoindex_banned_words_ignored_channels_1, :unique=>true
    end

    db.create_table?(:cams_channels_blacklist) do
      primary_key :id
    end
  end
end