#require "bundler/gem_tasks"
require 'csv'
require 'nokogiri'
require 'assembly-objectfile'

    
def get_checksum(md5_file)
  s = IO.read(md5_file)
  s.split('=')[1].strip
end

def write_out_xml(output_folder,cm)

  Dir.mkdir(output_folder) unless File.exists?(output_folder) # create the output directory if it doesn't exist

  # write out the previous druid XML file to the output directory, unless this is the first druid we are processing
  output_xml=File.join(output_folder,'contentMetadata.xml')
  puts "****writing to #{output_xml}"
  xml_file=File.open(output_xml,'w')
  xml_file.write cm.to_xml
  xml_file.close
  
end

def look_for_extra_files(cm,object_node,content_folder,file_attributes,druid)

  # check to see if images folder exists, and if so, iterate and add all images as new resource nodes   
  images_folder=File.join(content_folder,'Images')
  puts "looking in #{images_folder}"
  if File.exists? images_folder
    puts "found #{images_folder}"
    FileUtils.cd(images_folder)
    Dir.glob('*.jpg').each do |image_file|
      # create the resource node for the file
      puts "found #{image_file}"
      resource_node = Nokogiri::XML::Node.new("resource", cm)
      resource_node['type']='image'
      label_node = Nokogiri::XML::Node.new("label", cm)
      label_node.content=''
      resource_node << label_node
      create_file_node(resource_node,:filename=>image_file,:druid=>druid,:role=>'Images',:content_folder=>content_folder,:file_attributes=>file_attributes['image'])       
      object_node << resource_node        
    end
  end

  # check to see if transcript folder exists, and if so, iterate and add all transcripts as new resource nodes   
  transcript_folder=File.join(content_folder,'Transcript')
  puts "looking in #{transcript_folder}"
  if File.exists? transcript_folder
    puts "found #{transcript_folder}"
    FileUtils.cd(transcript_folder)
    Dir.glob('*.pdf').each do |transcript_file|
      # create the resource node for the file
      puts "found #{transcript_file}"
      resource_node = Nokogiri::XML::Node.new("resource", cm)
      resource_node['type']='text'
      label_node = Nokogiri::XML::Node.new("label", cm)
      label_node.content='Transcript'
      resource_node << label_node
      create_file_node(resource_node,:filename=>transcript_file,:druid=>druid,:role=>'Transcript',:content_folder=>content_folder,:file_attributes=>file_attributes['transcript'])       
      object_node << resource_node        
    end
  end
    
end

def create_file_node(resource_node,params={})
    
  base_path = 'http://dpgthumper2.stanford.edu/~pool0/smpl/SC1017_SOHP'
  
  filename=params[:filename]
  file_attributes=params[:file_attributes] || {}
  filetype=params[:filetype] || 'content'
  role=params[:role]
  filerole=params[:filerole] || ''
  druid=params[:druid]
  content_folder=params[:content_folder]
  
  file_node = Nokogiri::XML::Node.new("file", @cm)
  file_node['type']=filetype
  file_node['id']=filename
  file_node['role']=filerole unless filerole.empty?
  unless file_attributes.empty?
    file_node['publish']=file_attributes[:publish]
    file_node['preserve']=file_attributes[:preserve]
    file_node['shelve']=file_attributes[:shelve]
  end
  location_node = Nokogiri::XML::Node.new("location", @cm)
  location_node.content="#{base_path}/#{druid}/#{role}/#{filename}"
  file_node << location_node  

  if filetype=='content' # if we are dealing with a content filetype, check for an MD5 file and a techMD XML file and add as a additional filenodes if found

    md5_filename=filename + '.md5'
    md5_file=File.join(content_folder,role,md5_filename)
    if File.exists? md5_file
      checksum_node = Nokogiri::XML::Node.new("checksum", @cm)
      checksum_node['type']='md5'  
      checksum_node.content=get_checksum(md5_file)
      file_node << checksum_node
      create_file_node(resource_node,:filename=>md5_filename,:druid=>druid,:role=>role,:filetype=>'metadata',:filerole=>'checksum',:content_folder=>content_folder)
    end

    techmd_filename=File.basename(filename,'.*') + '_techmd.xml'
    techmd_file=File.join(content_folder,role,techmd_filename)
    if File.exists? techmd_file
      create_file_node(resource_node,:filename=>techmd_filename,:druid=>druid,:role=>role,:filetype=>'metadata',:filerole=>'techMD',:content_folder=>content_folder)
    end

  end
  
  resource_node << file_node
    
end
    
desc "Convert incoming spreadsheet from SMPL into XML file that will be produced.  Should only be temporarily needed until final XML is delivered."
task :prepare_smpl_content, :content_path, :csv_filename, :output_path, :source_id do |t, args|
  
  file_attributes={}
  file_attributes['pm']={:publish=>'no',:shelve=>'no',:preserve=>'yes'}
  file_attributes['sh']={:publish=>'no',:shelve=>'no',:preserve=>'yes'}
  file_attributes['sl']={:publish=>'yes',:shelve=>'no',:preserve=>'yes'}
  file_attributes['image']={:publish=>'yes',:shelve=>'yes',:preserve=>'yes'}
  file_attributes['text']={:publish=>'yes',:shelve=>'yes',:preserve=>'yes'}
  
  content_path = args[:content_path] || '/thumpers/dpgthumper2-smpl/SC1017_SOHP'
  csv_filename = args[:csv_filename] || 'config/projects/sohp_test.csv'
  output_path = args[:content_path] || '/tmp'
  source_id = args[:source_id] || 'SC1017_s1_Terman'
  
  puts "Content path: #{content_path}"
  puts "Input spreadsheet: #{csv_filename}"
  
  # keep track of which druid we just operated on, so we know when to start working on a new one (this is because the input CSV has more than one row per druid, but we only need one XML file per druid)
  previous_druid=''
  
  # iterate through the CSV
  CSV.foreach(csv_filename) do |row|
    
    # read the columns
    filename=row[0]
    label=row[1]
    sequence=row[2]
    
    # get the druid and file extensions
    filename_parts=File.basename(filename,'.*').split('_')
    druid=filename_parts[0]
    role=filename_parts[3]    
    file_extension=File.extname(filename)
    
    if druid != previous_druid # we have a new druid, so let's finish up all the bits for the previous one

      if previous_druid != '' # finish up by looking for images and transcripts for this druid and then write out the previous XML file (except for the first druid)
        
        look_for_extra_files(@cm,@object_node,@content_folder,file_attributes,previous_druid)
      
        write_out_xml(@output_folder,@cm)

      end
      puts "*** #{druid}"
      
      # generate the base of the XML file for this new druid
      @cm = Nokogiri::XML::Document.new
      @object_node = Nokogiri::XML::Node.new("object", @cm)
      @cm << @object_node
      identifiers_node = Nokogiri::XML::Node.new("identifiers", @cm)
      @object_node << identifiers_node
      ids=[]
      ids << Nokogiri::XML::Node.new("id", @cm)
      ids[0]['type']='local'
      ids[0]['name']='sourceID'
      ids[0].content=source_id
      identifiers_node << ids[0]
      ids << Nokogiri::XML::Node.new("id", @cm)
      ids[1]['type']='local'
      ids[1]['name']='druid'
      ids[1].content=druid
      identifiers_node << ids[1]

    end

    @content_folder=File.join(content_path,druid)   # this is the path to where the content is
    @output_folder=File.join(output_path,druid)     # this is the path to where we will write the resulting XML file (which could be the same as the content path)
        
    puts "operating on '#{filename}' with label '#{label}' -- sequence '#{sequence}', role '#{role}'"
    
    # create the resource node for the file
    resource_node = Nokogiri::XML::Node.new("resource", @cm)
    resource_node['type']='audio'
    resource_node['role']=role.downcase
    resource_node['seq']=sequence if sequence
    label_node = Nokogiri::XML::Node.new("label", @cm)
    label_node.content=label
    resource_node << label_node

    @object_node << resource_node
    
    # create the file node and attach it to the resource node, along with supplemenatry md5 and techMD nodes
    create_file_node(resource_node,:filename=>filename,:druid=>druid,:role=>role.upcase,:content_folder=>@content_folder,:file_attributes=>file_attributes[role.downcase])
       
    # set the previous druid so we know when we are starting a new one 
    previous_druid=druid
        
  end

  look_for_extra_files(@cm,@object_node,@content_folder,file_attributes,previous_druid)
  
  write_out_xml(@output_folder,@cm) # write out last XML file
  
end