# run with ruby devel/retrieve_content.rb
# must be run from lyberservices-prod to have access to all mounts and configuration

#!/usr/bin/env ruby
ENV['ROBOT_ENVIRONMENT']='production'  # environment to run under (i.e. which fedora instance to hit)

# search possible locations for object (new and old style)
def path_to_object(druid)
  DruidTools::Druid.new(druid,Dor::Config.content.content_base_dir).path() 
end

def content_folder(druid)
  File.join(path_to_object(druid),'content')
end

def metadata_folder(druid)
  File.join(path_to_object(druid),'metadata')
end

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

require 'pp'
require 'rubygems'
require 'dor-services'
require 'assembly-utils'
require 'logger'

@druids=%w{druid:wh714jd5922
           druid:zt360bf4956
           druid:rh819sf0365
           druid:cy818kd0872
           druid:rs804kc3617
           druid:hy850gj3726
           druid:zc633qx0677
           druid:hv240zr7497
           druid:gs197yh4784
           druid:cd312dr2057
           druid:gm988vp2189
           druid:xn387md2099
           druid:tb156mz0245
           druid:rh100zx3933
           druid:xm374zc9656
           druid:rt077kc5709
           druid:hr919sk0986
           druid:vy845jd6918
           druid:rp012bn5257
           druid:vy822kv2037
           druid:hn648vb3536
           druid:zk224ks6389
           druid:rz015cx6864
           druid:wm293gh2418
           druid:zp140wm0694
           druid:xs632sk4508
           druid:cp361gz0454
           druid:dt340xd5204
           druid:ht595nk2014
           druid:fn859jg2579
           druid:dm479hf3037
           druid:wb630cv9374
           druid:tt902nw2787
           druid:py875qc0136
           druid:ps176gv8310
           druid:kr778gf7793
           druid:fq330st8102
           druid:kd489xz1142
           druid:ts698mk0914
           druid:gs863yh1143
           druid:np434wx7761
           druid:bw171mw1036
           druid:pn264pz8940
           druid:hv577jx3178
         }
         
@druids.each do |druid|

  @fobj=Dor::Item.find(druid)
  puts "working on #{druid}"
  
  # create directories in /dor/workspace if they do not exist
  FileUtils.mkpath(path_to_object(druid)) unless File.directory?(path_to_object(druid))
  FileUtils.mkpath(content_folder(druid)) unless File.directory?(content_folder(druid))
  FileUtils.mkpath(metadata_folder(druid)) unless File.directory?(metadata_folder(druid))

  # write out content metadata from object unless a version already exists in the directory
  cm_file=File.join(metadata_folder(druid),'contentMetadata.xml')
  unless File.exists?(cm_file)
    File.open(cm_file, 'w') { |fh| fh.puts @fobj.contentMetadata.ng_xml.to_s }
    puts 'write contentMetadata.xml'
  end
  
  # figure out where the source content is (assuming only ludvigsen here)
  source_id=@fobj.identityMetadata.sourceId
  base_content_directory='/dor/staging/Revs/Ludvigsen/'
  content_subfolder=/LUDV-\d\d\d\d/.match(source_id).to_s.gsub('-','_')
  filename="#{source_id}.tif".gsub('Revs:','')
  source=File.join(base_content_directory,content_subfolder,filename)
  dest=File.join(content_folder(druid),filename)
  
  FileUtils.cp(source,dest) unless File.exists?(dest) && !File.exists?(source)

end         