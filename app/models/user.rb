class User < ApplicationRecord
  devise :remote_user_authenticatable # We don't want other (default) Devise modules
  has_many :bundle_contexts, dependent: :destroy
  validates :sunet_id, presence: true, uniqueness: true

  def email
    sunet_id.include?('@') ? sunet_id : "#{sunet_id}@stanford.edu"
  end
end
