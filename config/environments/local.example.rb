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
 
  solrizer.url 'https://dor-dev.stanford.edu/solr/'
  workflow.url 'http://lyberservices-dev.stanford.edu/workflow/'

  purl do
     base_url 'http://purl.stanford.edu/'
   end
   
  dor do
    service_root 'http://USERNAME:PASSWORD@lyberservices-dev.stanford.edu/dor/v1'
    num_attempts  5  # the number of attempts to contact the dor web service before throwing an exception
    sleep_time    10  # sleep time in seconds between attempts to contact the dor service    
    default_label 'Untitled' # the default label for an object that is registered when no label is provided in the manifest
  end

  remediation do
    check_for_versioning_required true  # this MUST be true in production; can be false in development and test if you want to ignore workflow checks 
    check_for_in_accessioning true  # this MUST be true in production; can be false in development and test if you want to ignore workflow checks 
  end
  
  content do
     content_user 'lyberadmin'
     content_base_dir '/dor/workspace/'
     content_server 'lyberservices-prod'
   end
   status do
     indexer_url 'http://sulstats-raw.stanford.edu//render/?format=json&from=-1minute&until=now&target=stats.gauges.dor-prod.argo.reindexqueue.queue-size.count'
   end
   stacks do
     document_cache_storage_root '/home/lyberadmin/document_cache'
     document_cache_host 'purl.stanford.edu'
     document_cache_user 'lyberadmin'
     local_workspace_root '/dor/workspace'
     storage_root '/stacks'
     host 'stacks.stanford.edu'
     user 'lyberadmin'
   end
  
end
