require 'dor-services'

Dor::Config.configure do
  ssl do
    cert_file Settings.dor_client_cert
    key_file Settings.dor_client_cert_key
  end

  # used to look up object existence in DOR for discovery report
  fedora do
    # used to look up objects in DOR
    url Settings.fedora_url
  end

  workflow do
    url Settings.workflow_url
  end
end
