# frozen_string_literal: true

# Model representing a Globus destination that can be used as a staging location.
class GlobusDestination < ApplicationRecord
  belongs_to :batch_context, optional: true
  belongs_to :user
end
