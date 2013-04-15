# run with ruby devel/add_and_update_files.rb
# must be run from lyberservices-prod to have access to all mounts and configuration

#!/usr/bin/env ruby
ENV['ROBOT_ENVIRONMENT']='production'  # environment to run under (i.e. which fedora instance to hit)

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

require 'rubygems'
require 'dor-services'
require 'assembly-utils'
require 'logger'
require 'net/ssh'

@dry_run=false # if set to true, then no operations are actually carried out, you only get notices of what will happen
start_limit=nil # objects to run from input array (set start_limit to nil for all)
end_limit=nil  # set end_limit to nil for all (or remainder if start_limit is not null)
#limit_to_druids=%w{tq270ry8164 gc161fd9389 bm916nx5550 dh941mm7815 vj818xc6811 wg983ft3682 wx067jz0783 yb570xw0261 yc460db1075 mh338cj3700 nz125bh9048 pk200tz2188 pz516hw4711 hp160sk3414 gb869zk5570} # limit to these druids (set to nil to do all druids)
limit_to_druids=%w{wg983ft3682}

@on_server = true # if true, then an attempt will be made to publish directly and SSH the file to the stacks; if false, this is not possible, so robots will be used

@base_path = '/dor/preassembly/ap_tei' # path where new files are located

@log_path = File.join(@base_path,'logs','add_and_update_files.log')
@log = Logger.new( @log_path, 'daily' )

@publish="yes"  # values for new files that need to be added
@preserve="yes"
@shelve="yes"

def parse_directory
  Dir.chdir(@base_path)
  files=Dir.glob('*/*.xml')
  puts "Found #{files.size} files"
  objects=[]
  files.each do |file|
    druid=file.split("/").first
    objects << {:filename=>file,:druid=>druid}
  end
  return objects
end

def add_or_replace_files(objects)
  
  puts ""
  puts Time.now
  @log.info Time.now
  puts "Environment: #{ENV['ROBOT_ENVIRONMENT']}"
  puts "Dry run" if @dry_run
  puts "Number of objects: #{objects.size}"
  @log.info "Number of objects: #{objects.size}"
  added=0
  replaced=0
  
  objects.each do |object|

    druid=object[:druid]
    file_path=object[:filename]   # name of file to add or replace
          
    puts "Working on #{druid} and #{file_path}"
    @log.info "Working on #{druid} and #{file_path}"

    path_to_new_file=File.join(@base_path,file_path)
    base_filename=File.basename(file_path)

    unless File.exists? path_to_new_file
  
      puts "*****New file '#{path_to_new_file}' not found" 
      @log.error "*****New file '#{path_to_new_file}' not found"

    else # we have our new file
  
      file=File.new(path_to_new_file)
  
      file_hash={}
      objectfile=Assembly::ObjectFile.new(path_to_new_file)
      unless @dry_run
        md5=objectfile.md5
        sha1=objectfile.sha1
        size=objectfile.filesize
        file_hash.merge!({:name=>base_filename,:md5 => md5, :size=>size.to_s, :sha1=>sha1})
      end
    
      item=Dor::Item.find("druid:#{druid}")
    
      object_location=path_to_object(druid,Dor::Config.content.content_base_dir) # get the path of this object in the workspace
      replacement_file_location=path_to_content_file(druid,Dor::Config.content.content_base_dir,base_filename)
  
      file_nodes=item.contentMetadata.ng_xml.search("//file[@id='#{base_filename}']")

      if file_nodes.size == 1 # file already exists in object

        # replace it
        puts "Replacing '#{base_filename}'"
        @log.info "Replacing '#{base_filename}'"
      
        existing_file=content_file(druid,Dor::Config.content.content_base_dir,base_filename)
        unless existing_file.nil? 
          puts "Deleting #{existing_file}"
          @log.info "Deleting #{existing_file}"
          FileUtils.rm(existing_file) unless @dry_run
        end
      
        puts "Copying from '#{path_to_new_file}' to '#{replacement_file_location}'"
        @log.info "Copying from '#{path_to_new_file}' to '#{replacement_file_location}'"
        FileUtils.cp(path_to_new_file,replacement_file_location) unless @dry_run
    
        item.contentMetadata.update_file(file_hash, base_filename) unless @dry_run
            
        replaced+=1
      
      else # file does not exist in object

        # add it 
        puts "Adding '#{base_filename}'"
   
        file_hash.merge!({:publish=>@publish,:shelve=> @shelve,:preserve => @preserve,:mime_type => objectfile.mimetype})

        puts "Copying from '#{path_to_new_file}' to '#{replacement_file_location}'"
        @log.info "Copying from '#{path_to_new_file}' to '#{replacement_file_location}'"
        FileUtils.cp(path_to_new_file,replacement_file_location) unless @dry_run

        # find object type resource
        resources=item.contentMetadata.ng_xml.search("//resource[@type='object']")
        if resources.length > 0 # found at least one object resource we can add the file too

          # get resource ID to add new file node in or add resource
          resource_id=resources[0]['id']

          item.contentMetadata.add_file(file_hash,resource_id) unless @dry_run
        
        elsif resources.length == 0 # we need to add a new object resource

          # create resource ID to add new file node in or add resource
          resource_id="#{item.pid.delete('druid:')}_object1"
        
          item.contentMetadata.add_resource([file_hash],resource_id,1,'object') unless @dry_run
                  
        end
      
        added+=1
          
      end
      
      publish("druid:#{druid}",item) if !@dry_run
      shelve("druid:#{druid}",path_to_new_file) if !@dry_run
    
    end

    puts ""
        
  end
  
  puts "Files added: #{added}"
  @log.info "Files added: #{added}"
  puts "Files replaced: #{replaced}"
  @log.info "Files replaced: #{replaced}"
  
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

def publish(druid,item)
  message=@on_server ? "Publishing metadata" : "Resetting publishing robot..."
  puts message
  @log.info message
  if @on_server
    item.publish_metadata
  else
    steps={'accessionWF' => ['publish']}  
    Assembly::Utils.reset_workflow_states(:druids=>[druid],:steps=>steps)
  end
end

def shelve(druid,path_to_new_file)
  message= @on_server ? "Shelving files" : "Resetting shelving robot..."
  puts message
  @log.info message
  if @on_server
    ssh_session=Net::SSH.start('stacks','lyberadmin')
    path_to_content= Dor::DigitalStacksService.stacks_storage_dir(druid)
    ssh_session.exec!("put #{path_to_new_file} #{path_to_content}")
    ssh_session.close if ssh_session
  else
    steps={'accessionWF' => ['shelve']}
    Assembly::Utils.reset_workflow_states(:druids=>[druid],:steps=>steps)
  end
end

objects=parse_directory

if start_limit
  end_limit=objects.size - 1 unless end_limit
  objects_to_run=objects[start_limit..end_limit]
else
  objects_to_run=objects
end

objects_to_run.reject!{|obj| !limit_to_druids.include? obj[:druid]} unless limit_to_druids.nil?

puts "Running #{objects_to_run.size} objects"
  
add_or_replace_files(objects_to_run)