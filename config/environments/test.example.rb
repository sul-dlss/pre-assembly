Dor::Config.configure do
  
  fedora do
    url 'https://sul-dor-test.stanford.edu/fedora'
  end
  
  ssl do
    cert_file File.join(CERT_DIR,"YOUR_CERT.crt")
    key_file  File.join(CERT_DIR,"YOUR_CERT.key")
    key_pass ''
  end
  
  suri do
    mint_ids true
    id_namespace 'druid'
    url 'http://sul-lyberservices-test.stanford.edu'
    user 'labware'
    pass 'lyberteam'
  end
   
  solrizer.url 'http://localhost:8080/solr/argo_test'
  workflow.url 'http://sul-lyberservices-test.stanford.edu/workflow/'

  purl do
     base_url 'http://purl-test.stanford.edu/'
   end

   remediation do
     check_for_versioning_required false  # this MUST be true in production; can be false in development and test if you want to ignore workflow checks 
     check_for_in_accessioning false  # this MUST be true in production; can be false in development and test if you want to ignore workflow checks 
   end
      
  dor do
    service_root 'https://dorAdmin:dorAdmin@sul-lyberservices-test.stanford.edu/dor/v1'
    num_attempts  3  # the number of attempts to contact the dor web service before throwing an exception
    sleep_time   2  # sleep time in seconds between attempts to contact the dor service    
    default_label 'Untitled' # the default label for an object that is registered when no label is provided in the manifest    
  end

  content do
     content_user 'lyberadmin'
     content_base_dir '/dor/workspace/'
     content_server 'lyberservices-test'
   end
   status do
     indexer_url 'http://sulstats-raw.stanford.edu//render/?format=json&from=-1minute&until=now&target=stats.gauges.dor-prod.argo.reindexqueue.queue-size.count'
   end
   stacks do
     document_cache_storage_root '/home/lyberadmin/document_cache'
     document_cache_host 'purl-test.stanford.edu'
     document_cache_user 'lyberadmin'
     local_workspace_root '/dor/workspace'
     storage_root '/stacks'
     host 'stacks-test.stanford.edu'
     user 'lyberadmin'
   end

end
