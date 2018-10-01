class User < ApplicationRecord
  devise :remote_user_authenticatable # We don't want other (default) Devise modules
  has_many :bundle_contexts
  validates :email, presence: true, uniqueness: true

  def sunet_id
    email.split('@').first
  end
end
