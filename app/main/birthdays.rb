require 'chronic'

# Crystal: Birthdays - A feature that allows users to set their birthdays, which are announced the day of (in UTC time).
module Bot::Birthdays
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  birthdays = DB[:birthdays]

  module_function

  # Makes sure that the given date is valid and returns a Date object (or nil if the date is invalid)
  def validate(date, &block)
    if date.match?(/\d+\/\d+/) || date.match?(/\d+\-\d+/)
      # "first" and "second" correspond to the first and second numbers of the date input respectively
      first, second = date.match?(/\d+\/\d+/) ? date.split("/").map(&:to_i) : date.split("-").map(&:to_i)

      if (first != second) && first <= 12 && second <= 12 
        first_date_possibility = Chronic.parse("#{first}/#{second}").strftime('%B %-d')
        second_date_possibility = Chronic.parse("#{second}/#{first}").strftime('%B %-d')
        date = block.call(first_date_possibility, second_date_possibility)
      end
    end

    birthday = Chronic.parse(date)
    return birthday.nil? ? birthday : Date.new(birthday.year, birthday.month, birthday.day)
  end

  # Cancels a command
  def cancel(event)
    result = loop do
      await_event = Bot::BOT.add_await!(Discordrb::Events::ReactionAddEvent, emoji: '❌')
      break :cancel if await_event.user == event.user
    end
    return result
  end

  # Gives a yes or no prompt with reacts
  def yes_or_no(event, prompt)
    prompt.react('✅')
    prompt.react('🚫')

    result = nil
    loop do
      reaction = Bot::BOT.add_await!(Discordrb::Events::ReactionAddEvent)
      next if reaction.user != event.user
      reaction.emoji.name == '🚫' ? result = false : result = true
      break
    end

    return result
  end

  # User commands

  # Allows a user to set their birthday
  command :setbirthday, aliases: [:setbday] do |event, *args|
    Bot::COMMAND_LOGGER.log(event, args)
    temp_msgs = Array.new

    delete_temp_msgs = -> {
      temp_msgs.each{ |m| m.delete }
    }

    bday_response = nil
    if args.empty?
      prompt = "Please enter your birthday. Acceptable format examples: 5/11 (month/day), 5-11 (month-day), " +
               "May 11, May 11th, 11 May, and 11th May. None of these examples are case sensitive. " +
               "Hit '❌' to cancel."
      bday_prompt = event.respond prompt
      bday_prompt.react('❌')
      temp_msgs.push(bday_prompt)

      Thread.new { bday_response = event.message.await!.content }
      Thread.new { bday_response = cancel(event) }
      sleep 0.05 until bday_response

      if bday_response == :cancel
        delete_temp_msgs.call
        event.respond "**Cancelled.**"
        break
      end
    end

    bday_date = validate(bday_response || args.join(" ")) do |date_one, date_two|
      view = Discordrb::Webhooks::View.new

      view.row do |r|
        r.button(style: 2, label: date_one, custom_id: "date one")
        r.button(style: 2, label: date_two, custom_id: "date two")
      end

      interaction_message = event.send("Which date did you mean? Choose one of the two options below.", false, nil, nil, nil, nil, view)
      temp_msgs.push(interaction_message)

      date = loop do
        button_event = event.bot.add_await!(Discordrb::Events::ButtonEvent, timeout: 180, custom_id: /date one|date two/)

        if button_event.nil?
          event.respond "**Timed out.**"
          return
        end
        
        if button_event.user.id != event.user.id
          button_event.defer_update
          next
        end

        chosen_date = date_one if button_event.custom_id == "date one"
        chosen_date = date_two if button_event.custom_id == "date two"

        button_event.update_message(content: interaction_message.content)

        break chosen_date
      end

      date
    end

    if bday_date.nil?
      delete_temp_msgs.call
      event.respond "**Invalid date.**"
      break
    end

    begin
      birthdays.insert(user_id: event.user.id, user: event.user.distinct, birthday: bday_date)
    rescue Sequel::UniqueConstraintViolation
      update_prompt = event.respond "#{event.user.mention}, your birthday is already registered with Zym. Would you like to update " +
      "your birthday to **#{bday_date.strftime('%B %-d')}**? Hit '✅' for yes, or '🚫' for no."
      temp_msgs.push(update_prompt)

      response = yes_or_no(event, update_prompt)

      if response
        delete_temp_msgs.call
        birthdays.where(user_id: event.user.id).update(birthday: bday_date)
        event.respond "Your birthday has been updated to **#{bday_date.strftime('%B %-d')}**."
      else
        delete_temp_msgs.call
        event.respond "**Cancelled.**"
        break
      end
    else
      announcement_prompt = event.respond "Would you like your birthday announced in our birthday channel? You will be mentioned in the message. " +
      "Press '✅' for yes or '🚫' for no."
      temp_msgs.push(announcement_prompt)

      announcement_allowed = yes_or_no(event, announcement_prompt)

      delete_temp_msgs.call
      birthdays.where(user_id: event.user.id).update(announcement: announcement_allowed)
      event.respond "Your birthday has been set to **#{bday_date.strftime('%B %-d')}.**"
    end
  end

  command :deletebirthday, aliases: [:deletebday, :delbday] do |event|
    Bot::COMMAND_LOGGER.log(event)
    temp_msgs = Array.new

    delete_prompt = event.respond "Are you sure you want to delete your birthday? Press '✅' for yes or '🚫' for no."
    response = yes_or_no(event, delete_prompt)
    temp_msgs.push(delete_prompt)

    temp_msgs[0].delete
    if response
      birthdays.where(user_id: event.user.id).delete == 0 ? (event.respond "**You don't have a registered birthday.**") : (event.respond "**Your birthday has been deleted.**")
    else
      event.respond "**Cancelled.**"
    end
  end

  command :announcement, aliases: [:ann] do |event|
    Bot::COMMAND_LOGGER.log(event)
    temp_msgs = Array.new

    announcement_setting = birthdays.where(user_id: event.user.id).get(:announcement)

    announcement_change_prompt = event.respond "Would you like to change whether or not you get mentioned in our birthday announcements " +
    "channel? Your current preference is: #{announcement_setting ? "`announce my birthday.`" : "`don't announce my birthday.`"} " +
    "Press '✅' to change your settings or '🚫' to keep them as they are."
    response = yes_or_no(event, announcement_change_prompt)
    temp_msgs.push(announcement_change_prompt)

    temp_msgs[0].delete
    if response
      birthdays.where(user_id: event.user.id).update(announcement: !announcement_setting)
      event.respond "**Your settings have been changed.**"
    else
      event.respond "**Cancelled.**"
    end
  end

  # Allows a user to view their birthday
  command :getbirthday, aliases: [:getbday] do |event, *args|
   Bot::COMMAND_LOGGER.log(event, args)
   args.empty? ? user = event.user : user = SERVER.get_user(args.join(" "))
   break if user.nil?

   bday = birthdays.where(user_id: user.id).get(:birthday)

   if bday.nil?
    event.respond "**Either you or the user you're trying to look up doesn't have a registered birthday with Zym.**"
   else
    event.respond "#{user == event.user ? "Your birthday" : "#{user.name}'s birthday"} is set to **#{bday.strftime('%B %-d')}.**"
   end
  end


  command :viewbirthdays, aliases: [:viewbdays, :view] do |event|
    Bot::COMMAND_LOGGER.log(event)

    temp_msgs = Array.new
    prompt_one = event.respond "What month would you like to view? Enter the number that corresponds to the option you want (without the dot), or press " +
    "'❌' to cancel. For reference, today is **#{Time.now.utc.strftime('%B %-d')}** (UTC)." +
    "\n1. January\n2. Feburary\n3. March\n4. April\n5. May\n6. June\n7. July\n8. August\n9. September\n10. October\n11. November\n12. December"
    temp_msgs.push(prompt_one)
    prompt_one.react('❌')

    response = nil
    Thread.new { response = event.message.await!.content.to_i }
    Thread.new { response = cancel(event) }
    sleep 0.05 until response

    temp_msgs[0].delete
    if (1..12).include? response
      bday_month_message = Array.new

      birthdays.order(:birthday).as_hash(:user, :birthday).each do |k, v|
        if v.month == response
          bday_month_message << "__Birthdays for #{v.strftime('%B')}__" if bday_month_message.empty?
          bday_month_message << "**#{k}:** #{v.strftime('%B %-d')}"
        end
      end

      bday_month_message.empty? ? (event.respond "**This month has no birthdays.**") : (event.channel.split_send(bday_month_message.join("\n")))
    elsif response == :cancel
      event.respond "**Cancelled.**"
    else
      event.respond "**Invalid value.**"
    end
  end

  member_leave do |event|
    birthdays.where(user_id: event.user.id).delete if birthdays.where(user_id: event.user.id).first
  end

  # Mod commands

  command :birthdays, aliases: [:bdays] do |event, *args|
    Bot::COMMAND_LOGGER.log(event, args)
    break unless event.user.has_permission?(:mod)

    prompt = event.respond "What would you like to do? React with the the option you want." +
      "\n1️⃣ Add user to database\n2️⃣ Change a user's birthday\n3️⃣ Delete a user from the database" +
      "\n4️⃣ Change a user's birthday announcements setting" +
      "\n5️⃣ Look up a user\n❌ Cancel the command"

    prompt.react('1️⃣')
    prompt.react('2️⃣')
    prompt.react('3️⃣')
    prompt.react('4️⃣')
    prompt.react('5️⃣')
    prompt.react('❌')

    delete_prompt = -> { prompt.delete }

    # An object containing methods that only mods can use
    mod_options = BirthdayModOptionMethods.new(event, birthdays)

    # Used to call the module methods 'validate' and 'cancel' from the 'BirthdayModOptionMethods' class
    call_module_methods = -> (method, value) do
      if method == :validate
        return validate(value)
      elsif method == :cancel
        return cancel(event)
      elsif method == :yes_or_no
        return yes_or_no(event, value)
      end
    end

    response = nil
    loop do
      await_event = Bot::BOT.add_await!(Discordrb::Events::ReactionAddEvent)
      next if await_event.user != event.user

      case await_event.emoji.name
      when '1️⃣'
        response = mod_options.add_user do |method, value|
          call_module_methods.(method, value)
        end
        break
      when '2️⃣'
        response = mod_options.change_bday do |method, value|
          call_module_methods.(method, value)
        end
        break
      when '3️⃣'
        response = mod_options.remove_user do |method, value|
          call_module_methods.(method, value)
        end
        break
      when '4️⃣'
        response = mod_options.change_announcement do |method, value|
          call_module_methods.(method, value)
        end
        break
      when '5️⃣'
        response = mod_options.search_user do |method, value|
          call_module_methods.(method, value)
        end
        break
      when '❌'
        response = "**Cancelled.**"
        break
      end
    end

    delete_prompt.call
    event.respond response
  end

  # Checks for birthdays at midnight UTC
  SCHEDULER.cron '0 0 * * * UTC' do
    birthday_role = Bot::BOT.role(ENV['BIRTHDAY_ROLE_ID'])
    birthday_role.members.each{ |mem| mem.remove_role(birthday_role) }

    # Sets the date using the UTC time as the base
    today_utc = Time.now.getgm
    utc_date = Date.new(today_utc.year, today_utc.month, today_utc.day)

    # Retrieves user ID's for users who have a birthday today and converts them into 'Member' objects
    bday_users_dataset = birthdays.select(:user_id).where(birthday: utc_date)
    bday_users = bday_users_dataset.map{ |uid| Bot::BOT.member(SERVER, uid[:user_id]) }
    bday_users.reject!{ |user| user.nil? }

    if bday_users.empty?
      next
    else
      # Array of users to be mentioned in the birthday announcement
      mentions = Array.new
      bday_users.each do |user|
        user.add_role(birthday_role)
        # Saves this user to the 'mentions' array if they allowed birthday announcements
        mentions << user.mention if birthdays.where(user_id: user.id).get(:announcement)
        birthdays.where(user_id: user.id).update(birthday: utc_date.next_year)
      end
      
      next if mentions.empty?

      birthday_channel = Bot::BOT.channel(ENV['BIRTHDAY_CHANNEL_ID'])
      birthday_channel.send_message "Happy birthday #{mentions.length > 1 ? mentions.join(", ") : mentions.join}!"
    end
  end
end