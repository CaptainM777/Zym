class BirthdayModOptionMethods
   include Constants

    def initialize(event, birthdays)
        @event = event
        @birthdays = birthdays
        @temp_msgs = Array.new
    end

    def retrieve_user
        name = @event.message.await!.content
        user = SERVER.get_user(name)
        return user
    end

    def add_user
        prompt_one = @event.respond "Enter the username or user ID of the user you want to add."
        @temp_msgs.push(prompt_one)
        user = retrieve_user

        if user.nil?
            @temp_msgs[0].delete
            return "**User not found.**"
        end

        prompt_two = @event.respond "Enter #{user.mention}'s birthday, or press '❌' to cancel."
        prompt_two.react('❌')
        @temp_msgs.push(prompt_two)

        response = nil
        Thread.new { response = @event.message.await!.content }
        Thread.new { response = yield(:cancel, nil) }
        sleep 0.05 until response

        if response == :cancel
          @temp_msgs.each{ |m| m.delete }
          return "**Cancelled.**"
        end

        prompt_three = @event.respond "Would you like this user's birthday to be announced in the birthdays channel? " +
        "Press '✅' to yes or '🚫' for no."
        @temp_msgs.push(prompt_three)

        announcement_setting = yield(:yes_or_no, prompt_three)

        @temp_msgs.each{ |m| m.delete }

        if response == :cancel
            return "**Cancelled.**"
        else
            bday = yield(:validate, response)

            return "**Invalid date.**" if bday.nil?

            begin
              @birthdays.insert(user.id, user.distinct, bday, announcement_setting)
            rescue Sequel::UniqueConstraintViolation => e
              puts "From add_user method: #{e}"
              return "**This user is already in the database.**"
            else
              return "#{user.mention} has been added with a birthday of **#{bday.strftime('%B %-d')}.**"
            end
        end
    end

    def remove_user
        prompt_one = @event.respond "Enter the username or user ID of the user you want to remove."
        @temp_msgs.push(prompt_one)
        user = retrieve_user

        if user.nil?
            @temp_msgs[0].delete
            return "**User not found.**"
        end

        prompt_two = @event.respond "Are you sure you want to delete #{user.mention} from the database?. Press '✅' for yes or '❌' to cancel."
        prompt_two.react('✅')
        prompt_two.react('❌')
        @temp_msgs.push(prompt_two)

        loop do
            reaction = Bot::BOT.add_await!(Discordrb::Events::ReactionAddEvent)
            next if reaction.user != @event.user

            if reaction.emoji.name == '❌'
                @temp_msgs.each{ |m| m.delete }
                return "**Cancelled.**"
            else
                result = @birthdays.where(user_id: user.id).delete
                @temp_msgs.each{ |m| m.delete }

                if result == 0
                    return "**User not found in the database.**"
                else
                    return "**Deleted #{user.mention} from the database.**"
                end
            end
        end
    end

    def change_bday
        prompt_one = @event.respond "Enter the username or user ID of the user whose birthday you want to change."
        @temp_msgs.push(prompt_one)
        user = retrieve_user

        if user.nil?
            @temp_msgs[0].delete
            return "**User not found.**"
        end

        retrieved_birthday = @birthdays.where(user_id: user.id).get(:birthday)

        if retrieved_birthday.nil?
            @temp_msgs[0].delete
            return "**#{user.mention} is not in the database.**"
        end

        prompt_two = @event.respond "#{user.mention}'s birthday is currently set to **#{retrieved_birthday.strftime('%B %-d')}**. " +
        "Please enter the date you want to replace it with (in this format: month/day or month-day), or press '❌' to cancel."
        prompt_two.react('❌')
        @temp_msgs.push(prompt_two)

        response = nil
        Thread.new { response = @event.message.await!.content }
        Thread.new { response = yield(:cancel, nil) }
        sleep 0.05 until response

        @temp_msgs.each{ |m| m.delete }

        if response == :cancel
            return "**Cancelled.**"
        else
            new_bday = yield(:validate, response)
            return "**Invalid date.**" if new_bday.nil?

            result = @birthdays.where(user_id: user.id).update(birthday: new_bday)
            return "#{user.mention}'s birthday has been set to **#{new_bday.strftime('%B %-d')}.**"
        end
    end

    def change_announcement
        prompt_one = @event.respond "Enter the username or user ID of the user whose birthday announcements setting you want to change."
        @temp_msgs.push(prompt_one)
        user = retrieve_user

        if user.nil?
            @temp_msgs[0].delete
            return "**User not found.**"
        end

        announcement_setting = @birthdays.where(user_id: user.id).get(:announcement)

        if announcement_setting.nil?
            @temp_msgs.each{ |m| m.delete }
            return "**#{user.mention} is not in the database.**"
        end

        prompt_two = @event.respond "#{user.mention}'s preference is set to: #{announcement_setting ? "`announce my birthday`" : "`don't announce my birthday`"}." +
        "Would you like to change this? Press '✅' to change their settings or '🚫' to keep them as they are."
        @temp_msgs.push(prompt_two)

        response = yield(:yes_or_no, prompt_two)

        if response
            @temp_msgs.each{ |m| m.delete }
            @birthdays.where(user_id: user.id).update(announcement: !announcement_setting)
            return "**#{user.mention}'s birthday announcements setting has been changed.**"
        else
            @temp_msgs.each{ |m| m.delete }
            return "**Cancelled.**"
        end
    end

    def search_user
      prompt_one = @event.respond "Enter the username or user ID of the user you want to look up."
      @temp_msgs.push(prompt_one)
      user = retrieve_user

      if user.nil?
        @temp_msgs[0].delete
        return "**User not found.**"
      end

      database_user = @birthdays.where(user_id: user.id).get([:birthday, :announcement])
      if database_user.nil?
        return "**Error retrieving user. The user is either not in the database or your search wasn't specific enough.**"
      else
        return "**User:** #{user.distinct}\n**Birthday:** #{database_user[0].strftime('%B %-d')}" +
        "\n**Allow birthday announcement?** #{database_user[1] ? "Yes" : "No"}"
      end
    end
end
