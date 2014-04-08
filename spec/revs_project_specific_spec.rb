require 'spec_helper'

describe PreAssembly::DigitalObject do

  before(:each) do
    @ps = {:apo_druid_id  => 'druid:qq333xx4444',:set_druid_id  => 'druid:mm111nn2222',:source_id => 'SourceIDFoo',:project_name => 'ProjectBar',:label=> 'LabelQuux',:project_style => {},:content_md_creation => {}}
    @dobj         = PreAssembly::DigitalObject.new @ps
    
    @dru          = 'gn330dv6119'
    @pid          = "druid:#{@dru}"
    @druid        = DruidTools::Druid.new @pid
    @tmp_dir_args = [nil, 'tmp']
    @dobj.object_files = []
    @dobj.desc_md_template_xml = <<-END.gsub(/^ {8}/, '')
      <?xml version="1.0"?>
      <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
        <typeOfResource>still image</typeOfResource>
        <genre authority="aat">digital image</genre>
        <subject authority="lcsh">
          <topic>Automobile</topic>
          <topic>History</topic>
        </subject>
        <% if !manifest_row[:location].blank? %>
       		<subject id="location" displayLabel="Location" authority="local">
      	    <hierarchicalGeographic>
        	<% manifest_row[:location].split(/[,|]/).reverse.each do |location| %>
      		  <% country=revs_get_country(location) 
      				 city_state=revs_get_city_state(location)
      		     if country %>
      			     	<country><%=country.strip%></country>
          	   <% elsif city_state %>
      	         <state><%=revs_get_state_name(city_state[1].strip)%></state>
      	         <city><%=city_state[0].strip%></city>
      				<% else %>
      					<citySection><%=location.strip%></citySection>
      				<% end %>           		  
      		<% end %>
      			</hierarchicalGeographic>
      		</subject>
      	<% end %>
      	<% if !manifest_row[:marque].blank? %>
      		<% manifest_row[:marque].split('|').each do |marque| %>
      			<% lc_term=revs_lookup_marque(marque.strip)
      			 if lc_term %>
      			    <subject displayLabel="Marque" authority="lcsh" authorityURI="http://id.loc.gov/authorities/subjects">
                 <topic valueURI="<%=lc_term['url']%>"><%=lc_term['value']%></topic>
               </subject>
    			   <% else %>
         			<subject displayLabel="Marque" authority="local">
         				<topic><%=marque.strip%></topic>
         			</subject>         			   
    			   <% end %>
      		<% end %>
        <% end %>           
        <relatedItem type="host">
          <titleInfo>
            <title>The Collier Collection of the Revs Institute for Automotive Research</title>
          </titleInfo>
          <typeOfResource collection="yes"/>
        </relatedItem>
        <relatedItem type="original">
          <physicalDescription>
            <form authority="aat"><%=revs_check_format(manifest_row[:format])%></form>
          </physicalDescription>
        </relatedItem>
        <originInfo>
          <dateCreated>[[year]]</dateCreated>
        </originInfo>
        <titleInfo>
          <title>'[[label]]' is the label!</title>
        </titleInfo>
        <note>[[description]]</note>
        <note>ERB Test: <%=manifest_row[:description]%></note>
        <identifier type="local" displayLabel="Revs ID">[[sourceid]]</identifier>
        <%if !manifest_row[:foo].blank?%><note type="source note" ID="foo"><%=manifest_row[:foo]%></note><% end %>
        <%if !manifest_row[:bar].blank?%><note type="source note" ID="bar"><%=manifest_row[:bar]%></note><% end %>
        <%if !manifest_row[:hide].blank? %><note type="source note" displayLabel="Visibility" ID="visibility">hidden</note><% end %>  
      </mods>
    END
    
  end

  ####################

   describe "revs specific descriptive metadata using special lookup methods, with a hidden image" do

     before(:each) do
       @dobj.druid = @druid
       @dobj.manifest_row = {
         :sourceid    => 'foo-1',
         :label       => 'this is < a label with an & that will break XML unless it is escaped',
         :year        => '2012',
         :marque      => 'Ford|Jaguar|Pegaso automobile|Suzuki automobiles',
         :description => 'this is a description > another description < other stuff',
         :format      => 'color transparency',
         :foo         =>  '123',
         :bar         =>  '456',
         :location    =>  'Bay Motor Speedway | San Mateo (Calif.) | United States',
         :hide        =>  'X'
       }
       @exp_xml = <<-END.gsub(/^ {8}/, '')
         <?xml version="1.0"?>
         <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
           <typeOfResource>still image</typeOfResource>
           <genre authority="aat">digital image</genre>
           <subject authority="lcsh">
             <topic>Automobile</topic>
             <topic>History</topic>
           </subject>
           <subject id="location" displayLabel="Location" authority="local">
             <hierarchicalGeographic>
               <country>United States</country>
               <state>California</state>
               <city>San Mateo</city>
               <citySection>Bay Motor Speedway</citySection>
             </hierarchicalGeographic>
           </subject>           
           <subject displayLabel="Marque" authority="lcsh" authorityURI="http://id.loc.gov/authorities/subjects">
             <topic valueURI="http://id.loc.gov/authorities/subjects/sh85050464">Ford automobile</topic>
           </subject>
           <subject displayLabel="Marque" authority="local">
             <topic>Jaguar</topic>
           </subject>    
           <subject displayLabel="Marque" authority="lcsh" authorityURI="http://id.loc.gov/authorities/subjects">
             <topic valueURI="http://id.loc.gov/authorities/subjects/sh94002401">Pegaso automobile</topic>
           </subject>                  
           <subject displayLabel="Marque" authority="lcsh" authorityURI="http://id.loc.gov/authorities/subjects">
             <topic valueURI="http://id.loc.gov/authorities/subjects/sh85130929">Suzuki automobile</topic>
           </subject>           
           <relatedItem type="host">
             <titleInfo>
               <title>The Collier Collection of the Revs Institute for Automotive Research</title>
             </titleInfo>
             <typeOfResource collection="yes"/>
           </relatedItem>
           <relatedItem type="original">
             <physicalDescription>
               <form authority="aat">color transparencies</form>
             </physicalDescription>
           </relatedItem>
           <originInfo>
             <dateCreated>2012</dateCreated>
           </originInfo>
           <titleInfo>
             <title>'this is &lt; a label with an &amp; that will break XML unless it is escaped' is the label!</title>
           </titleInfo>
           <note>this is a description &gt; another description &lt; other stuff</note>
           <identifier type="local" displayLabel="Revs ID">foo-1</identifier>
           <note>ERB Test: this is a description &gt; another description &lt; other stuff</note>
           <note type="source note" ID="foo">123</note>
           <note type="source note" ID="bar">456</note>
           <note type="source note" displayLabel="Visibility" ID="visibility">hidden</note>
         </mods>
       END
       @exp_xml = noko_doc @exp_xml
     end

     it "create_desc_metadata_xml() should generate the expected xml text" do
       @dobj.create_desc_metadata_xml
       noko_doc(@dobj.desc_md_xml).should be_equivalent_to @exp_xml
     end
     
   end

   describe "revs specific descriptive metadata using other lookup methods for location tags with just the country known" do

     before(:each) do
       @dobj.druid = @druid
       @dobj.manifest_row = {
         :sourceid    => 'foo-1',
         :label       => 'a label',
         :year        => '9/2/2012',
         :description => 'this is a description > another description < other stuff',
         :format      => 'film',
         :location    => 'Raceway , Rome , Italy',
         :foo         =>  nil,
         :bar         =>  ''
       }
       @exp_xml = <<-END.gsub(/^ {8}/, '')
       <?xml version="1.0"?>
       <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
         <typeOfResource>still image</typeOfResource>
         <genre authority="aat">digital image</genre>
         <subject authority="lcsh">
           <topic>Automobile</topic>
           <topic>History</topic>
         </subject>
         <subject id="location" displayLabel="Location" authority="local">
           <hierarchicalGeographic>
             <country>Italy</country>
             <citySection>Rome</citySection>
             <citySection>Raceway</citySection>
           </hierarchicalGeographic>
         </subject>
         <relatedItem type="host">
           <titleInfo>
             <title>The Collier Collection of the Revs Institute for Automotive Research</title>
           </titleInfo>
           <typeOfResource collection="yes"/>
         </relatedItem>
         <relatedItem type="original">
           <physicalDescription>
             <form authority="aat">film</form>
           </physicalDescription>
         </relatedItem>
         <originInfo>
           <dateCreated>9/2/2012</dateCreated>
         </originInfo>
         <titleInfo>
           <title>'a label' is the label!</title>
         </titleInfo>
         <note>this is a description  another description  other stuff</note>
         <note>ERB Test: this is a description  another description  other stuff</note>
         <identifier type="local" displayLabel="Revs ID">foo-1</identifier>
       </mods>
        END
       @exp_xml = noko_doc @exp_xml
     end

     it "create_desc_metadata_xml() should generate the expected xml text" do
       @dobj.create_desc_metadata_xml
       noko_doc(@dobj.desc_md_xml).should be_equivalent_to @exp_xml
     end

   end 

   describe "revs specific descriptive metadata using other lookup methods for location tags with no known entities" do

     before(:each) do
       @dobj.druid = @druid
       @dobj.manifest_row = {
         :sourceid    => 'foo-1',
         :label       => 'a label',
         :year        => '9/2/2012',
         :description => 'this is a description > another description < other stuff',
         :format      => 'black-and-white negative',
         :location    => 'Raceway | Random City | Random Country'
       }
       @exp_xml = <<-END.gsub(/^ {8}/, '')
       <?xml version="1.0"?>
       <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
         <typeOfResource>still image</typeOfResource>
         <genre authority="aat">digital image</genre>
         <subject authority="lcsh">
           <topic>Automobile</topic>
           <topic>History</topic>
         </subject>
         <subject id="location" displayLabel="Location" authority="local">
           <hierarchicalGeographic>
             <citySection>Random Country</citySection>
             <citySection>Random City</citySection>
             <citySection>Raceway</citySection>
           </hierarchicalGeographic>
         </subject>
         <relatedItem type="host">
           <titleInfo>
             <title>The Collier Collection of the Revs Institute for Automotive Research</title>
           </titleInfo>
           <typeOfResource collection="yes"/>
         </relatedItem>
         <relatedItem type="original">
           <physicalDescription>
             <form authority="aat">black-and-white negatives</form>
           </physicalDescription>
         </relatedItem>
         <originInfo>
           <dateCreated>9/2/2012</dateCreated>
         </originInfo>
         <titleInfo>
           <title>'a label' is the label!</title>
         </titleInfo>
         <note>this is a description  another description  other stuff</note>
         <note>ERB Test: this is a description  another description  other stuff</note>
         <identifier type="local" displayLabel="Revs ID">foo-1</identifier>
       </mods>
        END
       @exp_xml = noko_doc @exp_xml
     end

     it "create_desc_metadata_xml() should generate the expected xml text" do
       @dobj.create_desc_metadata_xml
       noko_doc(@dobj.desc_md_xml).should be_equivalent_to @exp_xml
     end

   end    
end