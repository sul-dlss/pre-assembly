class User < ApplicationRecord
  has_many :bundle_contexts
  validates :sunet_id, presence: true, uniqueness: true, null: false
end
