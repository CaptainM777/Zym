require 'discordrb'

module Interactivity
  CONTROL_BUTTONS = {
    'first': '⏮', 
    'previous': '◀', 
    'stop': '⏹', 
    'next': '▶', 
    'last': '⏭'
  }.freeze

  FIRST_PAGE_DISABLED_BUTTONS = [:first, :previous].freeze
  LAST_PAGE_DISABLED_BUTTONS = [:next, :last].freeze
  ONE_PAGE_DISABLED_BUTTONS = [:first, :previous, :next, :last].freeze
  STOP_DISABLED_BUTTONS = [:first, :previous, :stop, :next, :last].freeze

  # Message ID => 'Pages' instance
  ACTIVE_PAGES = {}

  Constants::SCHEDULER.every '30s' do
    ACTIVE_PAGES.each do |message_id, pages|
      if pages.timed_out
        invocation_channel = Bot::BOT.channel(pages.command_invocation_information.channel)
        buttons_message = invocation_channel.load_message(message_id) if !invocation_channel.nil?

        if !buttons_message.nil?
          embed, view = pages.stop
          buttons_message.edit("", embed, view.to_a)
        end

        ACTIVE_PAGES.delete(message_id)
      end
    end
  end

  def self.add_active_page(message_id, pages_obj)
    ACTIVE_PAGES[message_id] = pages_obj
  end

  class Pages
    attr_reader :timed_out, :command_invocation_information

    Command_Invocation_Information = Struct.new(:invoker, :channel)

    def initialize(logs, command_invoker, command_channel, **embed_parts)
      @pages = {}

      if logs.empty?
        @pages[1] = []
      else
        logs.each_slice(5).each_with_index do |page, index|
          @pages[index + 1] = page
        end
      end

      @command_invocation_information = Command_Invocation_Information.new(command_invoker, command_channel)
      
      @embed_parts = embed_parts
      @total_entries = logs.count
      @current_page = 1

      @timed_out = false
      @time_out_thread = create_time_out_thread
    end

    def generate_embed_and_pagination_controls(stop_pagination = false)
      embed = generate_embed(@current_page)
      view = create_pagination_controls(stop_pagination)

      return embed, view
    end

    def one_page?
      @pages.count == 1
    end

    def first_page? 
      @current_page == 1
    end

    def last_page?
      @current_page == @pages.count
    end

    def first_page
      @current_page = 1
      reset_timeout_thread
      generate_embed_and_pagination_controls(false)
    end

    def next_page
      @current_page += 1
      reset_timeout_thread
      generate_embed_and_pagination_controls(false)
    end

    def previous_page
      @current_page -= 1
      reset_timeout_thread
      generate_embed_and_pagination_controls(false)
    end

    def last_page
      @current_page = @pages.count
      reset_timeout_thread
      generate_embed_and_pagination_controls(false)
    end

    def stop
      @time_out_thread.kill
      generate_embed_and_pagination_controls(true)
    end

    private 

    def generate_embed(page_number)
      Discordrb::Webhooks::Embed.new(
        color: @embed_parts[:color],
        author: @embed_parts[:author],
        title: @embed_parts[:title],
        description: @embed_parts[:description],
        fields: @pages[page_number],
        footer: { text: "Page #{@current_page}/#{@pages.count}" }
      )
    end

    def create_pagination_controls(stop_pagination)
      view = Discordrb::Webhooks::View.new

      disabled_buttons = []
      if stop_pagination
        disabled_buttons += STOP_DISABLED_BUTTONS
      elsif one_page?
        disabled_buttons += ONE_PAGE_DISABLED_BUTTONS
      elsif first_page?
        disabled_buttons += FIRST_PAGE_DISABLED_BUTTONS
      elsif last_page?
        disabled_buttons += LAST_PAGE_DISABLED_BUTTONS
      end

      view.row do |r| 
        CONTROL_BUTTONS.each do |custom_id, emoji|
          r.button(
            custom_id: custom_id, 
            emoji: emoji, 
            style: 2,
            disabled: disabled_buttons.include?(custom_id.to_sym)
          )
        end
      end
  
      view
    end

    def reset_timeout_thread
      @time_out_thread.kill
      @time_out_thread = create_time_out_thread
    end

    def create_time_out_thread
      Thread.new do
        sleep 180
        @timed_out = true
      end
    end
  end

  Bot::BOT.button(custom_id: /first|previous|stop|next|last/) do |button_event|
    if !ACTIVE_PAGES[button_event.message.id]
      button_event.defer_update 
      next
    end

    if button_event.user.id != ACTIVE_PAGES[button_event.message.id].command_invocation_information.invoker
      button_event.respond(content: "You're not allowed to use these controls!", ephemeral: true)
      next
    end

    pages = ACTIVE_PAGES[button_event.message.id]
    button_name = button_event.custom_id

    case button_name
    when 'first'
      embed, view = pages.first_page
    when 'previous'
      embed, view = pages.previous_page
    when 'stop'
      embed, view = pages.stop
      ACTIVE_PAGES.delete(button_event.message.id)
    when 'next'
      embed, view = pages.next_page
    when 'last'
      embed, view = pages.last_page
    else
      next
    end

    button_event.update_message(components: view.to_a){ |builder, _| builder << embed }
  end
end