# run with ruby devel/add_and_update_files.rb
# must be run from lyberservices-prod to have access to all mounts and configuration

# TODO do we need to support the remote file location being old style?  this assumes all content files are in the base of druid tree

#!/usr/bin/env ruby
ENV['ROBOT_ENVIRONMENT']='test'  # environment to run under (i.e. which fedora instance to hit)
@dry_run=true # if set to true, then no operations are actually carried out, you only get notices of what will happen

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

@base_path = '/tmp' # path where new files are located
@publish="yes"  # values for new files that need to be added
@preserve="yes"
@shelve="yes"

objects=[
  {:druid=>'druid:bc001rm4583',:filename=>'2011-014HEWI-1955-b1_10.11_0001.tif'},
  {:druid=>'druid:bc104bp6427',:filename=>'2011-014HEWI-1954-b1_4.4_0002.tif'},
  {:druid=>'druid:bc104yg4412',:filename=>'bogus_name.tif'}
  ] # list of druids and filesnames to act on

require 'rubygems'
require 'dor-services'
require 'assembly-utils'
require 'logger'

def add_or_replace_files(objects)
  
  puts ""
  puts "Environment: #{ENV['ROBOT_ENVIRONMENT']}"
  puts "Dry run" if @dry_run
  puts ""

  objects.each do |object|

    druid=object[:druid]
    file_name=object[:filename]   # name of file to add or replace

    puts "Working on #{druid} and #{file_name}"
  
    path_to_new_file=File.join(@base_path,file_name)

    unless File.exists? path_to_new_file
    
      puts "*****New file '#{path_to_new_file}' not found" 
  
    else # we have our new file
    
      file=File.new(path_to_new_file)
    
      objectfile=Assembly::ObjectFile.new(path_to_new_file)
      md5=objectfile.md5
      sha1=objectfile.sha1
      size=objectfile.filesize
      file_hash={:name=>file_name,:md5 => md5, :size=>size.to_s, :sha1=>sha1}
    
      item=Dor::Item.find(druid)
      
      object_location=path_to_object(druid,Dor::Config.content.content_base_dir) # get the path of this object in the workspace
      replacement_file_location=path_to_content_file(druid,Dor::Config.content.content_base_dir,file_name)
    
      file_nodes=item.contentMetadata.ng_xml.search("//file[@id='#{file_name}']")

      if file_nodes.size == 1 # file already exists in object

        # replace it
        puts "Replacing '#{file_name}'"
      
        existing_file=content_file(druid,Dor::Config.content.content_base_dir,file_name)
        unless existing_file.nil? 
          puts "Deleting #{existing_file}"
          FileUtils.rm(existing_file) unless @dry_run
        end
        
        puts "Copying from '#{path_to_new_file}' to '#{replacement_file_location}'"
        FileUtils.cp(path_to_new_file,replacement_file_location) unless @dry_run
      
        item.contentMetadata.update_file(file_hash, file_name) unless @dry_run
        item.publish_metadata unless @dry_run
        item.shelve unless @dry_run
      
      else # file does not exist in object

        # add it 
        puts "Adding '#{file_name}'"
     
        file_hash.merge!({:publish=>@publish,:shelve=> @shelve,:preserve => @preserve,:mime_type => objectfile.mimetype})

        puts "Copying from '#{path_to_new_file}' to '#{replacement_file_location}'"
        FileUtils.cp(path_to_new_file,replacement_file_location) unless @dry_run

        # TODO Get resource ID to add new file node in
        resource="bc104yg4412_1"
      
        item.contentMetadata.add_file(file_hash,resource) unless @dry_run
  
        item.publish_metadata unless @dry_run
        item.shelve unless @dry_run
            
      end
  
    end
  
    puts ""
  
  end
end

# search possible locations for object (new and old style)
def path_to_object(druid,root_dir)
  path=nil
  new_path=druid_tree_path(druid,root_dir)
  old_path=old_druid_tree_path(druid,root_dir)
  if File.directory? new_path
    path = new_path 
  elsif File.directory? old_path
    path = old_path
  end
  return path
end

# new style path, e.g. aa/111/bb/2222/aa111bb2222
def druid_tree_path(druid,root_dir)
  DruidTools::Druid.new(druid,root_dir).path() 
end

# old style path, e.g. aa/111/bb/2222    
def old_druid_tree_path(druid,root_dir)
  Assembly::Utils.get_staging_path(druid,root_dir)
end

# returns the location of a content file, which can be in the old location if not found in the new location, e.g.  aa/111/bb/2222/aa111bb2222/content or  aa/111/bb/2222/    
def content_file(druid,root_dir,filename)
  if File.exists?(path_to_content_file(druid,root_dir,filename)) 
    return path_to_content_file(druid,root_dir,filename)
  elsif File.exists?(old_path_to_file(druid,root_dir,filename))
    return old_path_to_file(druid,root_dir,filename)
  else
    return nil
  end
end

# new style path to a content file, e.g.  aa/111/bb/2222/aa111bb2222/content
def path_to_content_file(druid,root_dir,file_name)
  if File.directory?(File.join path_to_object(druid,root_dir), "content")
    File.join path_to_object(druid,root_dir), "content", file_name
  else
    File.join path_to_object(druid,root_dir), file_name    
  end
end

# old style path to a file, without subfolder e.g.  aa/111/bb/2222/
def old_path_to_file(druid,root_dir,file_name)
  File.join path_to_object(druid,root_dir), file_name
end


add_or_replace_files(objects)