#! /usr/bin/env ruby
require File.expand_path(File.dirname(__FILE__) + '/../config/boot')


# Run with
# ROBOT_ENVIRONMENT=test bin/fix_incomplete_edistore_version_stanzas.rb PATH_TO_CSV_OF_DRUIDS
#CSV is expected to have headers of druid, dor_version, sdr_version


require 'rubygems'
require 'dor-services'
require 'dor-workflow-service'
require 'logger'
require 'csv'
require 'nokogiri'

#Load CSV and process it
CSV.foreach(ARGV[0], :headers => true) do |row|
  #puts row['druid']
  
  #Get the Item and datastream
  item = Dor::Item.find(row['druid'])
  vmd = item.datastreams['versionMetadata'].ng_xml
  
  #Remove All But the First Version (due to possible incomplete stanzas)
  v = 2
  while (v <= row['dor-version'].to_i) do
    vmd.xpath("//versionMetadata/version[@versionId=#{v}]").remove
    v+=1
  end
  
  #Create New Editstore Stanzas
  v = 2
  while(v <= row['sdr-version'].to_i+1) do
    new_version = Nokogiri::XML::Node.new 'version', vmd
    new_version['tag'] = "1.0.#{v-1}"
    new_version['versionId'] = v
    description = Nokogiri::XML::Node.new 'description', new_version
    description.content = "descriptive metadata update from editstore"
    new_version.add_child(description)
    vmd.children[0].add_child(new_version)
    v+=1
  end
  
  
  item.datastreams['versionMetadata'].content = vmd.to_xml
  item.versionMetadata.content_will_change!
  item.versionMetadata.save
  
  #Clear the accessionWF so we can make new versions
  # Dor::WorkflowService.delete_workflow('dor', row['druid'], 'accessionWF')
  
  #Replace the ones we just removed with new ones
  # v = 2
  # while(v <= row['sdr-version'].to_i+1) do
  #   Dor::WorkflowService.delete_workflow('dor', row['druid'], 'versioningWF')
  #   item.open_new_version(:assume_accessioned=>true) # we are already doing all of our checks to see if updates are allowe and versioning is required
  #   item.versionMetadata.update_current_version({:description => "descriptive metadata update from editstore",:significance => :admin})
  #   item.versionMetadata.content_will_change!
  #   item.versionMetadata.save
  #   v+=1
  # end
  
  #Restart The Accessioning WF
  Dor::WorkflowService.update_workflow_status 'dor', row['druid'], 'accessionWF', 'sdr-ingest-transfer', 'waiting'
  
  #Check for incomplete stanza
  #Delete incomplete stanza, lower number on all others
  #If no incomplete stanza, delete highest stanza 
  #Make sure no more than one total stanza is deleted or else we won't be in sync
  
  
  #Or nuke everything but version one and make n-2
  
  # <version tag="1.0.x-1" versionId="x">
 #     <description>descriptive metadata update from editstore</description>
 #   </version>
 #
 #   up to dorversion -1 = sdr +1 (remember we are keeping version 1)
  
end

