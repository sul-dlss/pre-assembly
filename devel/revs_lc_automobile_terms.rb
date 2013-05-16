# This file will generate a hash of LC more specific terms from the to-level term defined below (currently "Automobiles").
# It then dumps this hash to a file, so it can be loaded with each pre-assembly run and used when generating Revs Descriptive Metadata
# This method can be run periodically to refresh the list of terms.  It will generate a new file in the "lib/pre_assembly/project" folder
# which can be updated in git.

# Peter Mangiafico
# May 16, 2013

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require 'rdf/ntriples'

automobile_term='http://id.loc.gov/authorities/subjects/sh85010201' # the top-level LC term to get RDF for, "Automobiles"
term_predicate='http://www.w3.org/2004/02/skos/core#prefLabel' # the predicate which tells us when we have a term defined 

results={} # the hash we will write with the terms and their LC URLs

RDF::Reader.open("#{automobile_term}.nt") do |reader|
  reader.each_statement do |statement|
    if statement.predicate.to_s.strip == term_predicate
      results.merge!({statement.object.to_s=>statement.subject.to_s})
    end
  end
end

File.open(REVS_LC_TERMS_FILENAME, "wb") {|f| Marshal.dump(results, f)}