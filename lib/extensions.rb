# Server class from discordrb
class Discordrb::Server
  include Constants
  # Gets a member from a given string, either user ID, user mention, distinct (username#discrim),
  # nickname, or username on the given server; options earlier in the list take precedence (i.e.
  # someone with the username GeneticallyEngineeredInklings will be retrieved over a member
  # with that as a nickname) and in the case of nicknames and usernames, it checks for the beginning
  # of the name (i.e. the full username or nickname is not required)
  # @param  str [String]            the string to match to a member
  # @return     [Discordrb::Member] the member that matches the string, as detailed above; or nil if none found
  def get_user(str)
    return self.member(str.scan(/\d/).join.to_i) if self.member(str.scan(/\d/).join.to_i)
    members = self.members
    members.find { |m| m.distinct.downcase == str.downcase } ||
    members.find { |m| str.size >= 3 && m.display_name.downcase.start_with?(str.downcase) } ||
    members.find { |m| str.size >= 3 && m.name.downcase.start_with?(str.downcase) } ||
    members.find { |m| str.size >= 3 && m.display_name.downcase.include?(str.downcase) } ||
    members.find { |m| str.size >= 3 && m.name.downcase.include?(str.downcase) }
  end

  # Retrieves a role from whichever server the bot is currently using. The method returns nil unless the
  # given role exists on the server.
  # @param   [Discordrb::Role]         The requested role.
  # @return  [Discord::Role]           The retrieved role from the server, or nil if none was found.
  def get_role(role)
    return nil unless ROLE_NAMES.include?(role)
    ROLES.each do |r|
      if(r.name.downcase == role)
        return r
      end
    end
  end

  # Only accepts ID's and names for now
  def get_channel(channel)
    result = nil
    self.channels.each do |c|
      if(c.id == channel || c.name.downcase == channel || c.mention == channel)
        result = c
      end
    end
    return result
  end

  def get_zym_emotes
    server_emotes = self.emoji.values
    zym_emotes = server_emotes.select{ |em| em.name.start_with?("Zym") || em.name.start_with?("zym") }
    return zym_emotes
  end
end

# Message class from Discordrb
class Discordrb::Message
  include Constants
  # Creates a message link for a given message.
  # @return  [String]               The url.
  def jump_url
    return "https://discordapp.com/channels/#{self.channel.server.id}/#{self.channel.id}/#{self.id}"
  end
end

# User class from Discordrb
class Discordrb::User
  include Constants
  # Used for cases where 'Member' methods get called on 'User' objects
  def method_missing(method, *args, &block)
    return nil
  end

  def has_permission?(perm_to_check)
    return nil
  end
end

module Discordrb::Cache
  include Constants
  def role(name_or_id)
    server = server(SERVER_ID)

    id = name_or_id.resolve_id
    role = server.role(id)

    if role.nil?
      role = server.roles.find{ |r| r.name.downcase == name_or_id.downcase }
    end

    return role
  end
end

class Discordrb::Member
  include Constants
  def has_permission?(perm_to_check)
    if perm_to_check == :cap 
      return self.id == CAP_ID
    elsif perm_to_check == :admin
      return self.defined_permission?(:administrator) || self.id == CAP_ID
    elsif perm_to_check == :mod
      # Allows admins and I to use commands even if we don't have the mod role
      if self.id == CAP_ID || self.defined_permission?(:administrator) ||
         self.role?(ENV['MOD_ROLE_ID'])
        return true
      end
    end
    # Implicitly returns false if the above checks fail
    false
  end
end

class Discordrb::Message
  require 'open-uri'

  # For use in Discordrb::Message#convert_attachment; temporary solution
  class DrbStringIO < StringIO
    attr_accessor :path
  end

  def create_reactions(*reactions)
    reactions.each{ |reaction| create_reaction(reaction) }
  end

  def delete_reaction_all(reaction)
    users_who_reacted = reacted_with(reaction)
    users_who_reacted.each{ |user| delete_reaction(user, reaction) }
  end

  def convert_attachment
    return if attachments.empty?
    attachment = attachments[0]
    drbstringio = DrbStringIO.new(open(attachment.url).read)
    drbstringio.path = attachment.filename
    drbstringio
  end
end

class Discordrb::Bot
  include Constants
  def get_channel(channel)
    Bot::BOT.parse_mention(/<#\d+>/ =~ channel ? channel : "<##{channel}>")
  end
end

class Discordrb::Channel
  include Constants
  def purge_messages(amount, before_id, after_id)
    total_number_of_messages_deleted = 0

    loop do
      messages_to_be_deleted = history(amount, nil, after_id)

      if !after_id.nil? && !before_id.nil?
        if messages_to_be_deleted.count < 100
          messages_to_be_deleted.slice!(0..messages_to_be_deleted.find_index{ |m| m.id == before_id })
        end
      end

      amount_deleted = delete_messages(messages_to_be_deleted)
      total_number_of_messages_deleted += amount_deleted
      break if messages_to_be_deleted.count < 100
      after_id = messages_to_be_deleted[0]
    end

    total_number_of_messages_deleted
  end
end

class Discordrb::Embed
  # Code taken from: https://github.com/discordrb/discordrb/pull/705/commits/45196f0ca920205e957e3ccc679fd1c4ee03a2b3
  # Convert the embed to a embed for posting.
  # @example Send the embed of the posted message as it is.
  #   bot.message do |event|
  #     event.message.embeds.each {|embed| event.send_embed('', embed.to_postable) }
  #   end
  # @return [Webhooks::Embed] the embed object that can be sent by Webhook etc.
  def to_postable
    embed = Discordrb::Webhooks::Embed.new

    embed.title = @title
    embed.description = @description
    embed.url = @url
    embed.timestamp = @timestamp
    embed.color = @color

    embed.footer = Discordrb::Webhooks::EmbedFooter.new(
      text: @footer.text, icon_url: @footer.icon_url
    ) if @footer

    embed.image = Discordrb::Webhooks::EmbedImage.new(
      url: @image.url
    ) if @image

    embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(
      url: @thumbnail.url
    ) if @thumbnail

    embed.author = Discordrb::Webhooks::EmbedAuthor.new(
      name: @author.name, url: @author.url, icon_url: @author.icon_url
    ) if @author

    embed.fields = @fields.map do |field|
      Discordrb::Webhooks::EmbedField.new(
        name: field.name, value: field.value, inline: field.inline
      )
    end if @fields

    embed
  end
end