# require 'pstore'

# class Bot::Models::Giveaway < Sequel::Model
#   unrestrict_primary_key

#   ENTRANTS = PStore.new("#{ENV['DATA_PATH']}/giveaway_entrants.pstore")

#   def ended
#     Time.now > end_time
#   end

#   def add_entrants_for_reroll(entrants)
#     ENTRANTS.transaction{ ENTRANTS[id] = entrants.map(&:id) }
#   end

#   def entrants_stored_for_reroll?
#     ENTRANTS.transaction{ return ENTRANTS[id] }
#   end

#   def reroll_period_elapsed
#     (Time.now - end_time) >= 60
#   end

#   def clear_reroll_entrants
#     ENTRANTS.transaction{ ENTRANTS.delete(id) }
#   end

#   def after_destroy
#     super
#     clear_reroll_entrants
#   end
# end

# Migration file contents # Migration: AddGiveawaysTableToDatabase
# Sequel.migration do
#   change do
#     create_table(:giveaways) do
#       Integer :id, primary_key: true # ID is the giveaway message ID
#       Integer :channel_id
#       Integer :host
#       # Integer :job_id
#       Integer :length
#       Time :end_time
#       Integer :num_of_winners
#       String :prize
#     end
#   end
# end