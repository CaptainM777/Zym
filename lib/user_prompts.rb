require 'discordrb'
require_relative 'thread_lock'

class PromptManager
  def initialize(channel, user, embed: nil, timeout: nil, reaction: nil, clean: false)
    @channel = channel
    @user = user
    @embed = embed
    @timeout = timeout
    @reaction = reaction
    @clean = clean
  end

  def create(prompt_content, &block)
    Bot::BOT.prompt(
      @channel, 
      @user, 
      prompt_content, 
      embed: @embed, 
      timeout: @timeout, 
      reaction: @reaction, 
      clean: @clean,
      &block
    )
  end
end

# Adds additional methods to the Bot, Channel, User and Message classes in discordrb that prompt a user
# for a text response, with options to add a reaction button that cancels the prompt and a timeout in seconds.

class Discordrb::Bot
  # Prompts the given user for a response, blocking the thread until a response is given, the prompt is canceled or
  # times out. Can optionally set a timeout, add a reaction to be used as a cancel button, and clean after finished by
  # deleting the prompt and all responses. Accepts a block argument that runs every time a response is received; the
  # prompt will exit only if the block returns true.
  # @param       [Discordrb::Channel, String, Integer]   channel  the channel or its ID to send the prompt and
  #                                                               listen for responses in
  # @param       [Discordrb::User, String, Integer]      user     the user or their ID to listen for responses from
  # @param       [String]                                content  the text of the prompt message
  # @param       [String, nil]                           emoji    the emote to use for the cancel button
  # @param       [Integer, nil]                          timeout  the number of seconds elapsed for the prompt to
  #                                                               expire, or nil for no timeout
  # @param       [Boolean]                               clean    whether to clean up afterward by deleting the prompt
  #                                                               and all response messages
  # @return      [Discordrb::Message, nil]                        the message object of the response, or nil if it
  #                                                               timed out or was canceled
  # @yieldparam  [Discordrb::Message]                    message  the message object of the response
  # @yieldreturn [Boolean]                                        whether the given response is valid and the prompt
  #                                                               is able to exit
  def prompt(channel, user, content, emoji, timeout: nil, clean: false, &block)
    messages = Array.new
    lock = ThreadLock.new
    response = nil
    timeout_thread = nil
    message_handler, button_handler = nil, nil

    enabled_button_view = Discordrb::Webhooks::View.new
    enabled_button_view.row{ |r| r.button(custom_id: "cancel", emoji: emoji, style: 2)}

    # Send prompt message and add cancel button
    msg = self.send_message(channel, content, nil, nil, nil, nil, nil, enabled_button_view.to_a)
    messages.push(msg)

    # Define lambda that sets timeout on first call and resets timeout to max length on following calls (unless
    # no timeout is given)
    reset_timeout = lambda do
      next unless timeout
      timeout_thread.terminate if timeout_thread
      timeout_thread = Thread.new do
        sleep timeout
        channel.send "**Command timed out.**"
        lock.release
      end
    end

    reset_timeout.call

    # Define temporary handler for prompt response
    message_handler = message in: channel, from: user do |event|
      # If a block is given and returns false, reset the timeout
      if block && !block.call(event.message.content)
        reset_timeout.call

        # Otherwise, set response to event message and release lock
      else
        response = event.message
        lock.release
      end
    end

    # Define temporary handler for cancel button presses
    button_handler = button custom_id: "cancel" do |event|
      if event.user != user || event.message != msg
        event.defer_update
        next
      end

      event.respond(content: "**Command cancelled.**")
      lock.release
    end

    # Lock the thread until a valid response is given, prompt was canceled or timed out
    lock.close

    # Remove handlers and end timeout
    remove_handler(message_handler)
    remove_handler(button_handler)
    timeout_thread.terminate if timeout

    # Delete all messages if clean is enabled
    messages.each(&:delete) if clean

    # Return response (nil if prompt was canceled or timed out)
    response
  end
end

class Discordrb::Channel
  # Prompts the given user for a response in this channel.
  # @see Discordrb::Bot#prompt
  def prompt(user, content, emoji, timeout: nil, clean: false, &block)
    @bot.prompt(self, user, content, emoji, timeout: timeout, clean: clean, &block)
  end
end

class Discordrb::User
  # Prompts this user for a response in the given channel.
  # @see Discordrb::Bot#prompt
  def prompt(channel, content, emoji, timeout: nil, clean: false, &block)
    @bot.prompt(channel, self, content, emoji, timeout: timeout, clean: clean, &block)
  end
end

class Discordrb::Message
  # Prompts the author of this message for a response in the channel this message was sent in.
  # @see Discordrb::Bot#prompt
  def prompt(content, emoji, timeout: nil, clean: false, &block)
    @bot.prompt(self.channel, self.author, content, emoji, timeout: timeout, clean: clean, &block)
  end
end