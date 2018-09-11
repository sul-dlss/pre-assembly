RSpec.describe BundleContextTemporary do
  let(:revs_context) { context_from_proj(:proj_revs) }

  before { allow_any_instance_of(described_class).to receive(:validate_usage) } # to be replaced w/ AR validation

  describe "initialize() and other setup" do
    it 'requires params' do
      expect { described_class.new     }.to raise_error(ArgumentError)
      expect { described_class.new({}) }.to raise_error(ArgumentError)
    end

    it "trims the trailing slash from the bundle directory" do
      expect(revs_context.bundle_dir).to eq('spec/test_data/flat_dir_images')
    end

    it '#setup_other should prune @file_attr' do
      # All keys are present.
      expect(revs_context.file_attr.keys.map(&:to_s).sort).to eq(%w(preserve publish shelve))
      # Keys with nil values should be removed.
      revs_context.file_attr[:preserve] = nil
      revs_context.file_attr[:publish]  = nil
      revs_context.setup_other
      expect(revs_context.file_attr.keys).to eq([:shelve])
    end
  end

  describe '#validate_usage' do
    let(:fake_manifest) do
      [{ druid: '123', sourceid: 'xyz', label: 'obj_1', filename: 'foo.jpg' }.with_indifferent_access]
    end

    before do
      revs_context.user_params = Hash[revs_context.required_user_params.map { |p| [p, ''] }]
      allow_any_instance_of(described_class).to receive(:validate_usage).and_call_original # re-enable validation
    end

    it "does not raise an exception if requirements are satisfied" do
      allow(revs_context).to receive(:manifest_rows).and_return(fake_manifest)
      expect { revs_context.validate_usage }.not_to raise_error
    end

    it "raises exception if a user parameter is missing" do
      revs_context.user_params.delete :bundle_dir
      exp_msg = /^Configuration errors found:  Missing parameter: /
      expect { revs_context.validate_usage }.to raise_error(BundleUsageError, exp_msg)
    end

    it "raises exception if required directory not found" do
      revs_context.bundle_dir = '__foo_bundle_dir###'
      exp_msg = /^Configuration errors found:  Required directory not found/
      expect { revs_context.validate_usage }.to raise_error(BundleUsageError, exp_msg)
    end

    it "raises exception if required file not found" do
      revs_context.manifest = '__foo_manifest###'
      expect(File).to receive(:readable?).with(revs_context.manifest).and_return(false)
      expect { revs_context.validate_usage }.to raise_error(ArgumentError, /Required file not found/)
    end

    it "raises an exception since the sourceID column is misspelled" do
      exp_msg = /Manifest does not have a column called 'sourceid'/
      expect { context_from_proj(:proj_revs_bad_manifest).validate_usage }.to raise_error(BundleUsageError, exp_msg)
    end
  end

  describe '#setup_paths and defaults' do
    it "sets the staging_dir to the value specified in YAML" do
      expect(revs_context.staging_dir).to eq('tmp')
    end
    it "sets the progress log file to match the input yaml file if no progress log is specified in YAML" do
      expect(context_from_proj(:proj_sohp3).progress_log_file).to eq('spec/test_data/project_config_files/proj_sohp3_progress.yaml')
    end
    it "sets content_tag_override to the default value when not specified" do
      expect(revs_context.project_style[:content_tag_override]).to be_falsey
    end
  end

  describe '#staging_dir' do
    it 'takes default value' do
      expect(context_from_proj(:proj_sohp2).staging_dir).to eq('/dor/assembly')
    end
  end
end
