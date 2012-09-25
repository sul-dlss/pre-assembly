CERT_DIR = File.join(File.dirname(__FILE__), "..", "certs")

Dor::Config.configure do

  fedora do
    url 'http://USERNAME:PASSWORD@dor-dev.stanford.edu/fedora'
  end
  
  ssl do
    cert_file File.join(CERT_DIR,"dlss-dev-test.crt")
    key_file  File.join(CERT_DIR,"dlss-dev-test.key")
    key_pass ''
  end
  
  suri do
    mint_ids true
    id_namespace 'druid'
    url 'http://lyberservices-dev.stanford.edu'
    user 'labware'
    pass 'lyberteam'
  end

  metadata do
    exist.url 'http://viewer:l3l%40nd@lyberapps-prod.stanford.edu/exist/rest/'
    catalog.url 'http://lyberservices-prod.stanford.edu/catalog/mods'
  end
 
  gsearch.url  'https://dor-dev.stanford.edu/solr/gsearch'
  solrizer.url 'https://dor-dev.stanford.edu/solr/solrizer'
  workflow.url 'http://lyberservices-dev.stanford.edu/workflow/'

  dor do
    service_root 'http://USERNAME:PASSWORD@lyberservices-dev.stanford.edu'
    num_attempts  5  # the number of attempts to contact the dor web service before throwing an exception
    sleep_time    10  # sleep time in seconds between attempts to contact the dor service    
  end
  
end
