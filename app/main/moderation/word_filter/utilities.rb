module Bot::Moderation::WordFilter::Utilities
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  Bot::BOT.ready do
    sleep 0.5
    BOT_TEST_ID ||= (SERVER.name == 'The Dragon Prince' ? 841401988666884117 : 715360140051611690)
    BOT_TEST ||= Bot::BOT.channel(BOT_TEST_ID, SERVER)
  end

  module Constants; IGNORED_CHANNELS ||= Bot::DB[:banned_words_ignored_channels]; end

  def recipient_or_member?(user)
    return (user.respond_to?(:channel) ? SERVER.member(user.id) : user)
  end

  # Responds to the mod in chat when the "-bannedwords add" or "-bannedwords remove" command is used
  def respond_to_mod(command, words_array, event)
    words_array[0] = words_array[0].capitalize
    action = (command == :add ? "added to" : "removed from")
    has_or_have = (words_array.length == 1 ? "has" : "have")

    event.respond "`#{words_array.join(", ")}` #{has_or_have} been #{action} the banned word list."
    unless event.server
      BOT_TEST.send("A word or multiple words have been #{action} the banned words list. This was done in DM's by #{event.user.distinct}.")
    end
  end

  # Gives a simple yes or no prompt and returns the option that the user chooses
  def yes_or_no(prompt, event)
    prompt_message = event.respond prompt

    answer = nil
    loop do
      answer = event.user.await!.content.downcase
      break if answer == 'y' || answer == 'n'
      event.respond "Invalid input. Try again."
    end

    prompt_message.delete
    return answer
  end
end