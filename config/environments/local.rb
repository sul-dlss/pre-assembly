cert_dir = File.join(File.dirname(__FILE__), "..", "certs")

Dor::Config.configure do

  fedora do
    url 'http://fedoraAdmin:fedoraAdmin@dor-dev.stanford.edu/fedora'
  end

  ssl do
    cert_file File.join(cert_dir,"dlss-dev-test.crt")
    key_file  File.join(cert_dir,"dlss-dev-test.key")
    key_pass ''
  end

  suri do
    mint_ids true
    id_namespace 'druid'
    url 'http://lyberservices-dev.stanford.edu'
    user 'labware'
    pass 'lyberteam'
  end

  gsearch.url  'https://dor-dev.stanford.edu/solr/gsearch'
  solrizer.url 'https://dor-dev.stanford.edu/solr/solrizer'
  workflow.url 'http://lyberservices-dev.stanford.edu/workflow/'

  dor do
    service_root 'https://dorAdmin:dorAdmin@lyberservices-dev.stanford.edu'
  end

end
