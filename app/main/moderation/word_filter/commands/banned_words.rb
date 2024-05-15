require_relative '../utilities.rb'

module Bot::Moderation::WordFilter::Commands::BannedWords
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  extend Bot::Moderation::WordFilter::Utilities
  include Constants

  @@event = nil
  
  module_function

  def set_event(event)
    @@event = event
  end

  def add(words)
    words.map! do |word|
      begin
        DB[:banned_words].insert(word.downcase)
      rescue Sequel::UniqueConstraintViolation
        @@event << "`#{word.capitalize}` is already a banned word."
        nil
      else
        word.downcase
      end
    end

    words.reject!{ |word| word.nil? }

    respond_to_mod(:add, words, @@event) unless words.empty?
  end

  def remove(words)
    words.map! do |word|
      if DB[:banned_words][word: word.downcase]
        DB[:banned_words].where(word: word.downcase).delete
        word.downcase
      else
        @@event << "`#{word.capitalize}` isn't a banned word."
        nil
      end
    end

    words.reject!{ |word| word.nil? }

    respond_to_mod(:remove, words, @@event) unless words.empty?
  end

  def list
    banned_words = DB[:banned_words].all
    if banned_words.empty?
      @@event.respond "**There are no banned words in the list.**"
    else
      prompt = "**Make sure you have DM's turned on for this server so Zym bot can DM you the list.** " +
              "This list may contain words that are very offensive and triggering. " +
              "Are you sure you want to see the banned words list? Enter `y` for yes or `n` for no."
      answer = yes_or_no(prompt, @@event)

      if answer == 'n'
        @@event.respond "**Cancelled.**"
      else
        begin
          @@event.user.dm("**Banned words:** #{banned_words.map(&:values).join(", ")}")
        rescue Discordrb::Errors::NoPermission
          @@event.respond "**The list couldn't be DM'd to you because you don't have DM's turned on for this server.**"
        end
      end
    end
  end

  def clear
    prompt = "Are you sure you want to clear the banned words list? **This is irreversible.** " +
    "Enter `y` for yes or `n` to no."
    answer = yes_or_no(prompt, @@event)

    if answer == 'n'
      @@event.respond "**List clearing aborted.**"
    else
      DB[:banned_words].delete
      @@event.respond "**The banned words list has been cleared.**"
    end
  end
end