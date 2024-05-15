class Bot::Models::PrUserRole < Sequel::Model
  unrestrict_primary_key

  def get_role_id
    return id.split("_")[1].to_i # id.scan(/^\d+[^_]/)[1].to_i
  end
end