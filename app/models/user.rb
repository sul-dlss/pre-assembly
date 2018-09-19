class User < ApplicationRecord
  devise :remote_user_authenticatable # We don't want other (default) Devise modules
  has_many :bundle_contexts
  validates :sunet_id, presence: true, uniqueness: true, null: false

  def email
    sunet_id.include?('@') ? sunet_id : "#{sunet_id}@stanford.edu"
  end

end
