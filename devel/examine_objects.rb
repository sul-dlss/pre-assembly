# run with ruby devel/examine_objects.rb
# must be run from lyberservices-prod to have access to all mounts and configuration

#!/usr/bin/env ruby
ENV['ROBOT_ENVIRONMENT']='production'  # environment to run under (i.e. which fedora instance to hit)

# search possible locations for object (new and old style)
def path_to_object(druid,root_dir)
  new_path=druid_tree_path(druid,root_dir)
  old_path=old_druid_tree_path(druid,root_dir)
  return File.directory?(old_path) ? old_path : new_path
end

# new style path, e.g. aa/111/bb/2222/aa111bb2222
def druid_tree_path(druid,root_dir)
  DruidTools::Druid.new(druid,root_dir).path() 
end

# old style path, e.g. aa/111/bb/2222    
def old_druid_tree_path(druid,root_dir)
  Assembly::Utils.get_staging_path(druid,root_dir)
end

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

require 'pp'
require 'rubygems'
require 'dor-services'
require 'assembly-utils'
require 'logger'

@base_path = ['/dor/assembly','/dor/workspace']
          
@druids=%w{druid:wh714jd5922
           druid:ws012nq5164
           druid:sd586gp3826
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
  puts druid
  i=Dor::Item.find(druid)
  num_files=i.contentMetadata.ng_xml.xpath('//file').size
  num_tif=i.contentMetadata.ng_xml.xpath('//file[@mimetype="image/tiff"]').size
  num_jp2=i.contentMetadata.ng_xml.xpath('//file[@mimetype="image/jp2"]').size
  num_no_size=i.contentMetadata.ng_xml.xpath('//file[@size="0"]').size
  tif_filename=i.contentMetadata.ng_xml.xpath('//file[@mimetype="image/tiff"]/@id').text
  puts "num file nodes: #{num_files} | num tiff: #{num_tif} | num jp2: #{num_jp2} | num files with 0 size: #{num_no_size}"
  object_location=path_to_object(druid,Dor::Config.content.content_base_dir) # get the path of this object in the workspace
  cm_file=File.join(druid_tree_path(druid,Dor::Config.content.content_base_dir),'metadata','contentMetadata.xml')
  tif_file=File.join(druid_tree_path(druid,Dor::Config.content.content_base_dir),'content',tif_filename)
  puts "Workspace folder exists = #{File.directory?(object_location)}"
  puts "#{tif_file} exists = #{File.exists?(tif_file)}" unless (tif_filename.nil? || tif_filename == '')
  puts "#{cm_file} exists = #{File.exists?(cm_file)}"
#puts ''
 # pp i.contentMetadata.ng_xml.to_s
  puts '----'
end         