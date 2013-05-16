describe PreAssembly::DigitalObject do

  before(:each) do
    @ps = {
      :apo_druid_id  => 'druid:qq333xx4444',
      :set_druid_id  => 'druid:mm111nn2222',
      :source_id     => 'SourceIDFoo',
      :project_name  => 'ProjectBar',
      :label         => 'LabelQuux',
      :project_style => {},
      :content_md_creation => {}
    }
    @dobj         = PreAssembly::DigitalObject.new @ps
    
    @dru          = 'gn330dv6119'
    @pid          = "druid:#{@dru}"
    @druid        = DruidTools::Druid.new @pid
    @tmp_dir_args = [nil, 'tmp']
    @dobj.object_files = []
  end

  ####################

   describe "revs specific descriptive metadata using special lookup methods" do

     before(:each) do
       @dobj.druid = @druid
       @dobj.manifest_row = {
         :sourceid    => 'foo-1',
         :label       => 'this is < a label with an & that will break XML unless it is escaped',
         :year        => '2012',
         :marque      => 'Ford|Jaguar|Pegaso automobile|Suzuki automobiles',
         :description => 'this is a description > another description < other stuff',
         :format      => 'film',
         :foo         =>  '123',
         :bar         =>  '456',
       }
       @dobj.desc_md_template_xml = <<-END.gsub(/^ {8}/, '')
         <?xml version="1.0"?>
         <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
           <typeOfResource>still image</typeOfResource>
           <genre authority="att">digital image</genre>
           <subject authority="lcsh">
             <topic>Automobile</topic>
             <topic>History</topic>
           </subject>
         	<% if manifest_row[:marque] %>
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
               <form authority="att">[[format]]</form>
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
           <note type="source note" ID="foo">[[foo]]</note>
           <note type="source note" ID="bar">[[bar]]</note>
         </mods>
       END
       @exp_xml = <<-END.gsub(/^ {8}/, '')
         <?xml version="1.0"?>
         <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
           <typeOfResource>still image</typeOfResource>
           <genre authority="att">digital image</genre>
           <subject authority="lcsh">
             <topic>Automobile</topic>
             <topic>History</topic>
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
               <form authority="att">film</form>
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