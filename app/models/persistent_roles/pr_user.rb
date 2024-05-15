class Bot::Models::PrUser < Sequel::Model
  unrestrict_primary_key
  one_to_many :pr_user_roles

  def get_role_ids
    return pr_user_roles.map(&:get_role_id)
  end

  def before_destroy
    pr_user_roles.each{ |r| r.destroy }
    super
  end
end