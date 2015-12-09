require 'spec_helper'
require 'revs-utils'

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
    <%
      if !manifest_row[:date].blank?
        full_date = get_full_date(manifest_row[:date])
        pub_date = (full_date ?  full_date.strftime('%-m/%-d/%Y') : manifest_row[:date])
      elsif !manifest_row[:year].blank?
        pub_date = manifest_row[:year]
      else
        pub_date = nil
      end
    %>
    <?xml version="1.0"?>
    <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
      <typeOfResource>still image</typeOfResource>
      <genre authority="aat">digital image</genre>
      <subject displayLabel="Subject" authority="lcsh">
        <topic>Automobile</topic>
        <topic>History</topic>
      </subject>
      <% if !manifest_row[:marque].blank? %>
         <% manifest_row[:marque].split(/[,|]/).each do |marque| %>
           <% lc_term=revs_lookup_marque(marque.strip)
            if lc_term %>
               <subject displayLabel="Marque" authority="lcsh" authorityURI="http://id.loc.gov/authorities/subjects">
                <topic valueURI="<%=lc_term['url']%>"><%=marque.strip%></topic>
              </subject>
           <% else %>
              <subject displayLabel="Marque" authority="local">
                <topic><%=marque.strip%></topic>
              </subject>
           <% end %>
         <% end %>
       <% end %>
      <% if !manifest_row[:model].blank? %>
         <% manifest_row[:model].split(/[,|]/).each do |model| %>
        <subject displayLabel="Model" authority="local">
          <topic><%=model.strip%></topic>
        </subject>
        <% end %>
      <% end %>
      <% if !manifest_row[:people].blank? %>
        <% manifest_row[:people].split('|').each do |person| %>
          <subject displayLabel="People" authority="local">
            <name type="personal"><namePart><%=person.strip%></namePart></name>
          </subject>
        <% end %>
      <% end %>
      <% if !manifest_row[:entrant].blank? %>
        <% manifest_row[:entrant].split('|').each do |entrant| %>
          <subject id="entrant" displayLabel="Entrant" authority="local">
            <name type="personal"><namePart><%=entrant.strip%></namePart></name>
          </subject>
        <% end %>
      <% end %>
      <% if !manifest_row[:photographer].blank? %>
        <name id="photographer" displayLabel="Photographer" type="personal" authority="local">
          <namePart><%=manifest_row[:photographer].strip%></namePart>
          <role><roleTerm type="text" authorityURI="http://id.loc.gov/vocabulary/relators/pht">Photographer</roleTerm></role>
        </name>
      <% end %>
      <% if !manifest_row[:current_owner].blank? %>
        <subject id="current_owner" displayLabel="Current Owner" authority="local">
          <name type="personal"><namePart><%=manifest_row[:current_owner].strip%></namePart></name>
        </subject>
      <% end %>
      <% if !manifest_row[:venue].blank? %>
        <subject id="venue" displayLabel="Venue" authority="local">
          <topic><%=manifest_row[:venue].strip%></topic>
        </subject>
      <% end %>
      <% if !manifest_row[:track].blank? %>
        <subject id="track" displayLabel="Track" authority="local">
          <topic><%=manifest_row[:track].strip%></topic>
        </subject>
      <% end %>
      <% if !manifest_row[:event].blank? %>
        <subject id="event" displayLabel="Event" authority="local">
          <topic><%=manifest_row[:event].strip%></topic>
        </subject>
      <% end %>
      <% if !manifest_row[:country].blank? || !manifest_row[:city].blank? || !manifest_row[:state].blank?  %>
         <subject id="location" displayLabel="Location" authority="local">
          <hierarchicalGeographic>
             <%if !manifest_row[:country].blank? %>
                 <country><%=manifest_row[:country].strip%></country>
           <% end %>
             <% if !manifest_row[:state].blank? %>
                 <state><%=manifest_row[:state].strip%></state>
                <% end %>
             <% if !manifest_row[:city].blank? %>
                        <city><%=manifest_row[:city].strip%></city>
                <% end %>
          </hierarchicalGeographic>
        </subject>
      <% elsif !manifest_row[:location].blank? %>
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
      <% manifest_row[:format].split('|').each do |format| %>
        <relatedItem type="original">
          <physicalDescription>
            <form authority="<%= manifest_row[:format_authority].blank? ? "aat" : manifest_row[:format_authority]%>"><%=revs_check_format(format).strip%></form>
          </physicalDescription>
        </relatedItem>
      <% end %>
      <% if pub_date %>
        <originInfo keyDate="yes">
          <dateCreated><%=pub_date.strip%></dateCreated>
        </originInfo>
      <% end %>
      <titleInfo>
        <title><% if !manifest_row[:label].blank? %><%=manifest_row[:label].strip%><% end %></title>
      </titleInfo>
      <identifier type="local" displayLabel="Revs ID">[[sourceid]]</identifier>
      <% if !manifest_row[:description].blank? %><note displayLabel="Description"><%=manifest_row[:description].strip%></note><% end %>
      <% if !manifest_row[:model_year].blank? %><note displayLabel="Model Year" ID="model_year"><%=manifest_row[:model_year].strip%></note><% end %>
      <% if !manifest_row[:group_or_class].blank? %><note displayLabel="Group or Class" ID="group"><%=manifest_row[:group_or_class].strip%></note><% end %>
      <% if !manifest_row[:race_data].blank? %><note displayLabel="Race Data" ID="race_data"><%=manifest_row[:race_data].strip%></note><% end %>
      <% if !manifest_row[:metadata_sources].blank? %><note displayLabel="Metadata Sources" ID="metadata_sources"><%=manifest_row[:metadata_sources].strip%></note><% end %>
      <% if !manifest_row[:vehicle_markings].blank? %><note displayLabel="Vehicle Markings" ID="vehicle_markings"><%=manifest_row[:vehicle_markings].strip%></note><% end %>
      <% if !manifest_row[:inst_notes].blank? %><note type="source note" displayLabel="Institution Notes" ID="inst_notes"><%=manifest_row[:inst_notes].strip%></note><% end %>
      <% if !manifest_row[:prod_notes].blank? %><note type="source note" displayLabel="Production Notes" ID="prod_notes"><%=manifest_row[:prod_notes].strip%></note><% end %>
      <% if !manifest_row[:has_more_metadata].blank? %><note type="source note" displayLabel="Has More Metadata" ID="has_more_metadata">yes</note><% end %>
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
         :vehicle_markings         =>  '123',
         :inst_notes         =>  '456',
         :location    =>  'Bay Motor Speedway | San Mateo (Calif.) | United States',
         :hide        =>  'X'
       }
       @exp_xml = <<-END.gsub(/^ {8}/, '')
         <?xml version="1.0"?>
         <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
           <typeOfResource>still image</typeOfResource>
           <genre authority="aat">digital image</genre>
         <subject displayLabel="Subject" authority="lcsh">
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
             <topic valueURI="http://id.loc.gov/authorities/subjects/sh85050464">Ford</topic>
           </subject>
           <subject displayLabel="Marque" authority="local">
             <topic>Jaguar</topic>
           </subject>
           <subject displayLabel="Marque" authority="lcsh" authorityURI="http://id.loc.gov/authorities/subjects">
             <topic valueURI="http://id.loc.gov/authorities/subjects/sh94002401">Pegaso automobile</topic>
           </subject>
           <subject displayLabel="Marque" authority="lcsh" authorityURI="http://id.loc.gov/authorities/subjects">
             <topic valueURI="http://id.loc.gov/authorities/subjects/sh85130929">Suzuki automobiles</topic>
           </subject>
           <relatedItem type="original">
             <physicalDescription>
               <form authority="aat">color transparencies</form>
             </physicalDescription>
           </relatedItem>
          <originInfo keyDate="yes">
             <dateCreated>2012</dateCreated>
           </originInfo>
           <titleInfo>
             <title>this is &lt; a label with an &amp; that will break XML unless it is escaped</title>
           </titleInfo>
           <identifier type="local" displayLabel="Revs ID">foo-1</identifier>
           <note displayLabel="Description">this is a description &gt; another description &lt; other stuff</note>
           <note displayLabel="Vehicle Markings" ID="vehicle_markings">123</note>
           <note type="source note" displayLabel="Institution Notes" ID="inst_notes">456</note>
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
         :date        => '9/2/2012',
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
         <subject displayLabel="Subject" authority="lcsh">
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
         <relatedItem type="original">
           <physicalDescription>
             <form authority="aat">film</form>
           </physicalDescription>
         </relatedItem>
          <originInfo keyDate="yes">
           <dateCreated>9/2/2012</dateCreated>
         </originInfo>
         <titleInfo>
           <title>a label</title>
         </titleInfo>
         <identifier type="local" displayLabel="Revs ID">foo-1</identifier>
         <note displayLabel="Description">this is a description  another description  other stuff</note>
       </mods>
        END
       @exp_xml = noko_doc @exp_xml
     end

     it "create_desc_metadata_xml() should generate the expected xml text" do
       @dobj.create_desc_metadata_xml
       noko_doc(@dobj.desc_md_xml).should be_equivalent_to @exp_xml
     end

   end

   describe "revs specific descriptive metadata using other lookup methods for location tags with no known entities and multiple formats with format correction, and preserving some odd date value" do

     before(:each) do
       @dobj.druid = @druid
       @dobj.manifest_row = {
         :sourceid    => 'foo-1',
         :label       => 'a label',
         :date        => 'something weird',
         :format      => 'black-and-white negative| color transparencies',
         :year        => 'blot',
         :description => 'this is a description > another description < other stuff',
         :location    => 'Raceway | Random City | Random Country'
       }
       @exp_xml = <<-END.gsub(/^ {8}/, '')
       <?xml version="1.0"?>
       <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
         <typeOfResource>still image</typeOfResource>
         <genre authority="aat">digital image</genre>
         <subject displayLabel="Subject" authority="lcsh">
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
         <relatedItem type="original">
           <physicalDescription>
             <form authority="aat">black-and-white negatives</form>
           </physicalDescription>
         </relatedItem>
         <relatedItem type="original">
           <physicalDescription>
             <form authority="aat">color transparencies</form>
           </physicalDescription>
         </relatedItem>
         <originInfo keyDate="yes">
           <dateCreated>something weird</dateCreated>
         </originInfo>
         <titleInfo>
           <title>a label</title>
         </titleInfo>
         <identifier type="local" displayLabel="Revs ID">foo-1</identifier>
         <note displayLabel="Description">this is a description  another description  other stuff</note>
       </mods>
        END
       @exp_xml = noko_doc @exp_xml
     end

     it "create_desc_metadata_xml() should generate the expected xml text" do
       @dobj.create_desc_metadata_xml
       noko_doc(@dobj.desc_md_xml).should be_equivalent_to @exp_xml
     end

   end

   describe "use specific location fields instead of generic location field" do

     it "should create revs specific descriptive metadata using city, state and country fields instead of location and using a year" do
       @dobj.druid = @druid
       @dobj.manifest_row = {
         :sourceid    => 'foo-1',
         :label       => 'a label',
         :year        => '2012',
         :description => 'this is a description > another description < other stuff',
         :format      => 'black-and-white negative',
         :location    => '',
         :city        => 'Berlin',
         :country     => 'Germany'
       }
       @exp_xml = <<-END.gsub(/^ {8}/, '')
       <?xml version="1.0"?>
       <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
         <typeOfResource>still image</typeOfResource>
         <genre authority="aat">digital image</genre>
         <subject displayLabel="Subject" authority="lcsh">
           <topic>Automobile</topic>
           <topic>History</topic>
         </subject>
         <subject id="location" displayLabel="Location" authority="local">
           <hierarchicalGeographic>
             <country>Germany</country>
             <city>Berlin</city>
           </hierarchicalGeographic>
         </subject>
         <relatedItem type="original">
           <physicalDescription>
             <form authority="aat">black-and-white negatives</form>
           </physicalDescription>
         </relatedItem>
         <originInfo keyDate="yes">
           <dateCreated>2012</dateCreated>
         </originInfo>
         <titleInfo>
           <title>a label</title>
         </titleInfo>
         <identifier type="local" displayLabel="Revs ID">foo-1</identifier>
         <note displayLabel="Description">this is a description  another description  other stuff</note>
       </mods>
        END
       @exp_xml = noko_doc @exp_xml
       @dobj.create_desc_metadata_xml
       noko_doc(@dobj.desc_md_xml).should be_equivalent_to @exp_xml
     end

     it "should create revs specific descriptive metadata using city, state and country fields instead of location with location field left off" do
       @dobj.druid = @druid
       @dobj.manifest_row = {
         :sourceid    => 'foo-1',
         :label       => 'a label',
         :date        => '9/2/2012',
         :description => 'this is a description > another description < other stuff',
         :format      => 'black-and-white negative',
         :entrant     => 'Donald Duck | Mickey Mouse',
         :city        => 'Munich',
         :state       => 'Bavaria',
         :country     => 'Germany'
       }
       @exp_xml = <<-END.gsub(/^ {8}/, '')
       <?xml version="1.0"?>
       <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
         <typeOfResource>still image</typeOfResource>
         <genre authority="aat">digital image</genre>
         <subject displayLabel="Subject" authority="lcsh">
           <topic>Automobile</topic>
           <topic>History</topic>
         </subject>
         <subject id="location" displayLabel="Location" authority="local">
           <hierarchicalGeographic>
             <country>Germany</country>
             <state>Bavaria</state>
             <city>Munich</city>
           </hierarchicalGeographic>
         </subject>
         <subject id="entrant" displayLabel="Entrant" authority="local">
           <name type="personal">
             <namePart>Donald Duck</namePart>
           </name>
         </subject>
          <subject id="entrant" displayLabel="Entrant" authority="local">
           <name type="personal">
             <namePart>Mickey Mouse</namePart>
           </name>
         </subject>
         <relatedItem type="original">
           <physicalDescription>
             <form authority="aat">black-and-white negatives</form>
           </physicalDescription>
         </relatedItem>
         <originInfo keyDate="yes">
           <dateCreated>9/2/2012</dateCreated>
         </originInfo>
         <titleInfo>
           <title>a label</title>
         </titleInfo>
         <identifier type="local" displayLabel="Revs ID">foo-1</identifier>
         <note displayLabel="Description">this is a description  another description  other stuff</note>
       </mods>
        END
       @exp_xml = noko_doc @exp_xml
       @dobj.create_desc_metadata_xml
       noko_doc(@dobj.desc_md_xml).should be_equivalent_to @exp_xml
     end

     it "should create revs specific descriptive using alternate two year date format" do
       @dobj.druid = @druid
       @dobj.manifest_row = {
         :sourceid    => 'foo-1',
         :label       => 'a label',
         :date        => '05/12/55',
         :entrant     => 'Donald Duck',
         :description => 'this is a description > another description < other stuff',
         :format      => 'black-and-white negative',
         :city        => 'Munich',
         :state       => 'Bavaria',
         :country     => 'Germany',
         :location    => nil
       }
       @exp_xml = <<-END.gsub(/^ {8}/, '')
       <?xml version="1.0"?>
       <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
         <typeOfResource>still image</typeOfResource>
         <genre authority="aat">digital image</genre>
         <subject displayLabel="Subject" authority="lcsh">
           <topic>Automobile</topic>
           <topic>History</topic>
         </subject>
         <subject id="location" displayLabel="Location" authority="local">
           <hierarchicalGeographic>
             <country>Germany</country>
             <state>Bavaria</state>
             <city>Munich</city>
           </hierarchicalGeographic>
         </subject>
         <subject id="entrant" displayLabel="Entrant" authority="local">
           <name type="personal">
             <namePart>Donald Duck</namePart>
           </name>
         </subject>
         <relatedItem type="original">
           <physicalDescription>
             <form authority="aat">black-and-white negatives</form>
           </physicalDescription>
         </relatedItem>
         <originInfo keyDate="yes">
           <dateCreated>5/12/1955</dateCreated>
         </originInfo>
         <titleInfo>
           <title>a label</title>
         </titleInfo>
         <identifier type="local" displayLabel="Revs ID">foo-1</identifier>
         <note displayLabel="Description">this is a description  another description  other stuff</note>
       </mods>
        END
       @exp_xml = noko_doc @exp_xml
       @dobj.create_desc_metadata_xml
       noko_doc(@dobj.desc_md_xml).should be_equivalent_to @exp_xml
     end

     it "should create revs specific descriptive metadata using alternate date format and ignoring the bad year field" do
       @dobj.druid = @druid
       @dobj.manifest_row = {
         :sourceid    => 'foo-1',
         :label       => 'a label',
         :date        => '1965-04-12',
         :year        => 'some crap',
         :entrant     => 'Donald Duck',
         :description => 'this is a description > another description < other stuff',
         :format      => 'black-and-white negative',
         :city        => 'Munich',
         :state       => 'Bavaria',
         :country     => 'Germany',
         :location    => nil
       }
       @exp_xml = <<-END.gsub(/^ {8}/, '')
       <?xml version="1.0"?>
       <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
         <typeOfResource>still image</typeOfResource>
         <genre authority="aat">digital image</genre>
         <subject displayLabel="Subject" authority="lcsh">
           <topic>Automobile</topic>
           <topic>History</topic>
         </subject>
         <subject id="location" displayLabel="Location" authority="local">
           <hierarchicalGeographic>
             <country>Germany</country>
             <state>Bavaria</state>
             <city>Munich</city>
           </hierarchicalGeographic>
         </subject>
         <subject id="entrant" displayLabel="Entrant" authority="local">
           <name type="personal">
             <namePart>Donald Duck</namePart>
           </name>
         </subject>
         <relatedItem type="original">
           <physicalDescription>
             <form authority="aat">black-and-white negatives</form>
           </physicalDescription>
         </relatedItem>
         <originInfo keyDate="yes">
           <dateCreated>4/12/1965</dateCreated>
         </originInfo>
         <titleInfo>
           <title>a label</title>
         </titleInfo>
         <identifier type="local" displayLabel="Revs ID">foo-1</identifier>
         <note displayLabel="Description">this is a description  another description  other stuff</note>
       </mods>
        END
       @exp_xml = noko_doc @exp_xml
       @dobj.create_desc_metadata_xml
       noko_doc(@dobj.desc_md_xml).should be_equivalent_to @exp_xml
     end

     it "should create revs specific descriptive metadata using date range with years" do
       @dobj.druid = @druid
       @dobj.manifest_row = {
         :sourceid    => 'foo-1',
         :label       => 'a label',
         :date        => '1965-1969',
         :entrant     => 'Donald Duck',
         :description => 'this is a description > another description < other stuff',
         :format      => 'black-and-white negative',
         :city        => 'Munich',
         :state       => 'Bavaria',
         :country     => 'Germany',
         :location    => nil
       }
       @exp_xml = <<-END.gsub(/^ {8}/, '')
       <?xml version="1.0"?>
       <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
         <typeOfResource>still image</typeOfResource>
         <genre authority="aat">digital image</genre>
         <subject displayLabel="Subject" authority="lcsh">
           <topic>Automobile</topic>
           <topic>History</topic>
         </subject>
         <subject id="location" displayLabel="Location" authority="local">
           <hierarchicalGeographic>
             <country>Germany</country>
             <state>Bavaria</state>
             <city>Munich</city>
           </hierarchicalGeographic>
         </subject>
         <subject id="entrant" displayLabel="Entrant" authority="local">
           <name type="personal">
             <namePart>Donald Duck</namePart>
           </name>
         </subject>
         <relatedItem type="original">
           <physicalDescription>
             <form authority="aat">black-and-white negatives</form>
           </physicalDescription>
         </relatedItem>
         <originInfo keyDate="yes">
           <dateCreated>1965-1969</dateCreated>
         </originInfo>
         <titleInfo>
           <title>a label</title>
         </titleInfo>
         <identifier type="local" displayLabel="Revs ID">foo-1</identifier>
         <note displayLabel="Description">this is a description  another description  other stuff</note>
       </mods>
        END
       @exp_xml = noko_doc @exp_xml
       @dobj.create_desc_metadata_xml
       noko_doc(@dobj.desc_md_xml).should be_equivalent_to @exp_xml
     end

     it "should create revs specific descriptive metadata with no date or year" do
       @dobj.druid = @druid
       @dobj.manifest_row = {
         :sourceid    => 'foo-1',
         :label       => 'a label',
         :entrant     => 'Donald Duck',
         :description => 'this is a description > another description < other stuff',
         :format      => 'black-and-white negative',
         :city        => 'Munich',
         :state       => 'Bavaria',
         :country     => 'Germany',
         :location    => nil
       }
       @exp_xml = <<-END.gsub(/^ {8}/, '')
       <?xml version="1.0"?>
       <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
         <typeOfResource>still image</typeOfResource>
         <genre authority="aat">digital image</genre>
         <subject displayLabel="Subject" authority="lcsh">
           <topic>Automobile</topic>
           <topic>History</topic>
         </subject>
         <subject id="location" displayLabel="Location" authority="local">
           <hierarchicalGeographic>
             <country>Germany</country>
             <state>Bavaria</state>
             <city>Munich</city>
           </hierarchicalGeographic>
         </subject>
         <subject id="entrant" displayLabel="Entrant" authority="local">
           <name type="personal">
             <namePart>Donald Duck</namePart>
           </name>
         </subject>
         <relatedItem type="original">
           <physicalDescription>
             <form authority="aat">black-and-white negatives</form>
           </physicalDescription>
         </relatedItem>
         <titleInfo>
           <title>a label</title>
         </titleInfo>
         <identifier type="local" displayLabel="Revs ID">foo-1</identifier>
         <note displayLabel="Description">this is a description  another description  other stuff</note>
       </mods>
        END
       @exp_xml = noko_doc @exp_xml
       @dobj.create_desc_metadata_xml
       noko_doc(@dobj.desc_md_xml).should be_equivalent_to @exp_xml
     end

     it "should create revs specific descriptive metadata with an alternate format authority" do
       @dobj.druid = @druid
       @dobj.manifest_row = {
         :sourceid    => 'foo-1',
         :label       => 'a label',
         :entrant     => 'Donald Duck',
         :description => 'this is a description > another description < other stuff',
         :format      => 'black-and-white negative',
         :format_authority => 'alternate'
       }
       @exp_xml = <<-END.gsub(/^ {8}/, '')
       <?xml version="1.0"?>
       <mods xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
         <typeOfResource>still image</typeOfResource>
         <genre authority="aat">digital image</genre>
         <subject displayLabel="Subject" authority="lcsh">
           <topic>Automobile</topic>
           <topic>History</topic>
         </subject>
         <subject id="entrant" displayLabel="Entrant" authority="local">
           <name type="personal">
             <namePart>Donald Duck</namePart>
           </name>
         </subject>
         <relatedItem type="original">
           <physicalDescription>
             <form authority="alternate">black-and-white negatives</form>
           </physicalDescription>
         </relatedItem>
         <titleInfo>
           <title>a label</title>
         </titleInfo>
         <identifier type="local" displayLabel="Revs ID">foo-1</identifier>
         <note displayLabel="Description">this is a description  another description  other stuff</note>
       </mods>
        END
       @exp_xml = noko_doc @exp_xml
       @dobj.create_desc_metadata_xml
       noko_doc(@dobj.desc_md_xml).should be_equivalent_to @exp_xml
     end

   end

end