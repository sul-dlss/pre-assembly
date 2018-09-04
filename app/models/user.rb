class User < ApplicationRecord
  validates :sunet_id, presence: true, uniqueness: true
end
