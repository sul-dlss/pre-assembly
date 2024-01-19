# frozen_string_literal: true

# Starts the accession workflow by calling dor-services-app
# See https://sul-dlss.github.io/dor-services-app/#operation/objects#accession
class StartAccession
  def self.run(druid:, user:, workflow: nil)
    object_client = Dor::Services::Client.object(druid)

    object_client.accession.start(
      significance: 'major',
      description: 'pre-assembly re-accession',
      opening_user_name: user,
      workflow:
    )
  end
end
