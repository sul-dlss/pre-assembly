# frozen_string_literal: true

# Model representing a single SDR item that is accessioned as part of a job run.
class Accession < ApplicationRecord
  belongs_to :job_run

  enum :state, in_progress: 'in_progress', completed: 'completed', failed: 'failed'
end
