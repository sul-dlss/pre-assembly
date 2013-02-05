#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

current_path = File.dirname(File.expand_path(__FILE__))

require 'rubygems'
require 'dor-services'
require 'assembly-utils'
require 'logger'

@base_path = '/home/lyberadmin/jlavigne/BnF/update/'
@mods_path = @base_path + 'mods/'
@log_path = @base_path + 'logs/'

@log = Logger.new( @log_path + 'upd_descMD_frda.log', 'daily' )

##########################
def get_file_path(file)
##########################

  if file !~ /#{@base_path}/
    file = @base_path + file
  end

  return file

end # get_file_path

####################
def check_args(args)
####################

 if args.size != 2 
   return -1
 elsif ! File.exists?(get_file_path(args[0])) &&
       ! File.exists(get_file_path(args[1])) 
    return -1 
 else
    return 0
 end

end # check_args

#############################
def get_pid_to_file(pf_file)
############################

  pf_lines = IO.readlines(get_file_path(pf_file)).map { |x| x.chomp }

  pid_to_file = Hash.new
  pf_lines.each do |l|
    pid, file = l.split(/,/)
    pid_to_file[pid] = file
  end

  return pid_to_file

end # get_pid_to_file

#####################
def cleanup_guill(xml) # Change pseudo guillaumets to simple quotation marks
#####################

   #xml.gsub!(/&lt;&lt;/, '&laquo;') # guillaumet entities don't come through Nokogiri
   #xml.gsub!(/&gt;&gt;/, '&raquo;')
   xml.gsub!(/&lt;&lt;/, '"')
   xml.gsub!(/&gt;&gt;/, '"')

   return xml

end #cleanup_guill

##################
def get_title(xml)
##################

  new_title = ''
  doc = Nokogiri::XML(xml, &:default_html)
  doc.encoding = 'UTF-8'
  if doc.xpath('//xmlns:mods/xmlns:titleInfo/xmlns:title').length == 1
    new_title = doc.xpath('//xmlns:mods/xmlns:titleInfo/xmlns:title').inner_html
  end

  return new_title

end # get_title

##############################
def read_xml(pid, pid_to_file) # Get XML based on pid (druid)
##############################
  file = pid_to_file[pid]
  @log.info "Using file #{@mods_path}#{file} for pid #{pid}"
  return IO.read(@mods_path + file)
end

##########
def main() # Iterate over file of pid/druids to change
##########

  if check_args(ARGV) != 0
    puts "Please enter the name of a pid + filename file followed by " +
         "the name of a file of pids to process."
    exit
  end

  # Get pid_to_file hash
  pid_to_file = get_pid_to_file(get_file_path(ARGV[0]))

  File.open(get_file_path(ARGV[1])).each do |pid|
    
    pid.chomp!
    @log.info '====================='
    @log.info "#{Time.now.to_s}"
    @log.info "Processing pid #{pid}"

    changes_made = 0

    #puts "Getting object .."
    obj = Dor::Item.find(pid)
    #puts "obj descMetadata  is " + obj.datastreams['descMetadata'].to_xml

    # Get XML from file if available & use to change descMetadata and identityMetadata 
    #puts "Getting XML file ..."
    if pid_to_file[pid] and File.exists?("#{@mods_path}#{pid_to_file[pid]}")
      xml_dm = read_xml(pid, pid_to_file)
      xml_dm = cleanup_guill(xml_dm)
      new_title = get_title(xml_dm) # get new_title here to use below for identityMetadata
      # Replace descMetadata
      #puts "new title is #{new_title}"
      obj.datastreams['descMetadata'].content = xml_dm
      obj.descMetadata.content_will_change!
      # Replace title in identityMetadata
      doc_id = obj.identityMetadata.ng_xml
      if doc_id.xpath('//identityMetadata/objectLabel').length == 1 and
        ( new_title != '' or ! new_title.nil? )
        idm = doc_id.xpath('//identityMetadata/objectLabel')
        idm[0].content = new_title
        obj.datastreams['identityMetadata'].content = doc_id.to_xml
        obj.identityMetadata.content_will_change!
      end
      changes_made += 1
    else
      @log.info "No MODS file found for pid #{pid}" 
    end

    # Get Nokokiri doc for this obj and delete descMetadata.xml resource if present
    #puts "Getting Nokogiri doc ..."
    doc = obj.contentMetadata.ng_xml
    if doc.xpath('//contentMetadata/resource/file[@id="descMetadata.xml"]').length == 1
      nodes = doc.xpath('//contentMetadata/resource/file[@id="descMetadata.xml"]')
      raise "Warning! found more or less than 1 file node with id descMetadata.xml" unless nodes.size == 1
      nodes.first.parent.remove
      doc = Nokogiri.XML(doc.to_xml, &:noblanks)
      obj.datastreams['contentMetadata'].content = doc.to_xml
      obj.contentMetadata.content_will_change!
      changes_made += 1
    else
      @log.info "No descMetadata found in contentMetadata for pid #{pid}" 
    end

    # Save changes to object
    #puts "Saving object ..."
    if changes_made > 0
      obj.save
      @log.info "#{changes_made} changes saved for #{pid}"
    else
      @log.info "No changes to save for #{pid}"
    end
  end
end

main()
