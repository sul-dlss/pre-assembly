RSpec.describe BundleContextController, type: :controller do
  context 'GET index' do
    let(:bc) do
      BundleContext.new(
        project_name: "Smoke Test",
        content_structure: "simple_image",
        content_metadata_creation: "default",
        bundle_dir: "spec/test_data/bundle_input_b",
        user: user
      )
    end

    it "renders the index template" do
      get :index
      expect(response).to render_template("index")
    end
    it "is successful" do
      get :index
      expect(response.status).to eq(200)
    end
  end

  context "POST create" do
    context "Valid Parameters" do
      let(:bc) { BundleContext.find_by(project_name: 'Smoke Test') }

      before do
        post :create, params: { project_name: "Smoke Test",
                                content_structure: "simple_image",
                                content_metadata_creation: "default",
                                bundle_dir: "spec/test_data/bundle_input_b" }
      end

      it "passes valid params" do
        expect(response.status).to eq(200)
      end
      it 'saves BundleContext in db' do
        expect(bc).to be_an_instance_of BundleContext
      end
      it 'has the correct attributes' do
        expect(bc.project_name).to eq 'Smoke Test'
        expect(bc.content_structure).to eq "simple_image"
        expect(bc.content_metadata_creation).to eq "default"
        expect(bc.bundle_dir).to eq "spec/test_data/bundle_input_b"
      end
      it 'calls preassembly job when job_selection is Pre-Assembly Job' do
        # TODO: test PreassemblyJob.perform_later when job_selection is "Pre-Assembly Job"
      end
      it 'calls discovery report job when job_selection is Discovery Report' do
        # TODO: test DiscoveryReportJob.performat_later when job_select is "Discovery Report"
      end
    end

    context "Invalid Parameters" do
      let(:post_create) { post :create }

      let(:bc) { BundleContext.find_by(bundle_dir: "spec/test_data/bundle_input_b") }

      before do
        post :create, params: { project_name: nil,
                                content_structure: "simple_image",
                                content_metadata_creation: "default",
                                bundle_dir: "spec/test_data/bundle_input_b" }
      end

      it 'passes invalid params' do
        expect(bc).to be_nil
        expect(post_create).to render_template(:index)
      end
    end
  end
end
