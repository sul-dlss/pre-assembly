RSpec.describe BundleContextTemporary do
  let(:revs_context) { context_from_proj(:proj_revs) }

  describe "initialize() and other setup" do
    it "trims the trailing slash from the bundle directory" do
      expect(revs_context.bundle_dir).to eq('spec/test_data/bundle_input_a')
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
    before { revs_context.user_params = Hash[revs_context.required_user_params.map { |p| [p, ''] }] }

    it '#required_files should return expected N of items' do
      expect(revs_context.required_files.size).to eq(2)
      revs_context.manifest = nil
      expect(revs_context.required_files.size).to eq(1)
      revs_context.checksums_file = nil
      expect(revs_context.required_files.size).to eq(0)
    end

    it "does not raise an exception if requirements are satisfied" do
      expect { revs_context.validate_usage }.not_to raise_error
    end

    it "raises exception if a user parameter is missing" do
      revs_context.user_params.delete :bundle_dir
      exp_msg = /^Configuration errors found:  Missing parameter: /
      expect { revs_context.validate_usage }.to raise_error(PreAssembly::BundleUsageError, exp_msg)
    end

    it "raises exception if required directory not found" do
      revs_context.bundle_dir = '__foo_bundle_dir###'
      exp_msg = /^Configuration errors found:  Required directory not found/
      expect { revs_context.validate_usage }.to raise_error(PreAssembly::BundleUsageError, exp_msg)
    end

    it "raises exception if required file not found" do
      revs_context.manifest = '__foo_manifest###'
      exp_msg = /^Configuration errors found:  Required file not found/
      expect { revs_context.validate_usage }.to raise_error(PreAssembly::BundleUsageError, exp_msg)
    end
  end

  describe '#setup_paths and defaults' do
    it "sets the staging_dir to the value specified in YAML" do
      # revs.setup_paths
      expect(revs_context.staging_dir).to eq('tmp')
    end

    it "sets the progress log file to match the input yaml file if no progress log is specified in YAML" do
      # b = described_class.new(context_from_proj(:proj_sohp3))
      # b.setup_paths
      expect(context_from_proj(:proj_sohp3).progress_log_file).to eq('spec/test_data/project_config_files/proj_sohp3_progress.yaml')
    end

    it "sets content_tag_override to the default value when not specified" do
      expect(revs_context.project_style[:content_tag_override]).to be_falsey
    end

    it "sets the staging_dir to the default value if not specified in the YAML" do
      default_staging_directory = Assembly::ASSEMBLY_WORKSPACE
      if File.exist?(default_staging_directory) && File.directory?(default_staging_directory)
        # b = described_class.new(context_from_proj(:proj_sohp2))
        # b.setup_paths
        expect(context_from_proj(:proj_sohp2).staging_dir).to eq(default_staging_directory)
      else
        expect { context_from_proj(:proj_sohp2) }.to raise_error BundleUsageError
      end
    end
  end
end
