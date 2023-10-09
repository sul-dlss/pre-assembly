# frozen_string_literal: true

RSpec.describe 'batch_contexts/show.html.erb' do
  let(:bc) { create(:batch_context_with_deleted_output_dir, :with_globus_destination) }

  before { assign(:batch_context, bc) }

  it 'displays BatchContext info' do
    render template: 'batch_contexts/show'
    expect(rendered).to include("Project: #{bc.project_name}")
    expect(rendered).to include('no')
    expect(rendered).to include('Globus')
  end

  it 'has buttons for new Jobs' do
    render template: 'batch_contexts/show'
    expect(rendered).to include('<input type="submit" name="commit" value="Run Preassembly"')
    expect(rendered).to include('<input type="submit" name="commit" value="New Discovery Report"')
  end

  it 'does not display job summary if none exist' do
    render template: 'batch_contexts/show'
    expect(rendered).not_to include('Jobs summary')
  end

  context 'when job runs exist' do
    let!(:job_run) { create(:job_run, batch_context: bc) }

    # When a `JobRun` instance is created, it is initially in the `waiting`
    # state, but an ActiveRecord create callback[^1] is called instantly which
    # kicks off a job that instantly transitions the job to `running`[^2]. This
    # means that whether or not the job run is waiting or running is dependent
    # on how quickly that job runs during the test. To avoid a flappy spec
    # situation, disable the callback only for this one spec.
    #
    # [^1]: https://github.com/sul-dlss/pre-assembly/blob/main/app/models/job_run.rb#L12
    # [^2]: https://github.com/sul-dlss/pre-assembly/blob/main/app/models/job_run.rb#L48
    around do |example|
      JobRun.skip_callback(:commit, :after, :enqueue!)
      example.run
      JobRun.set_callback(:commit, :after, :enqueue!)
    end

    it 'displays job summary' do
      render template: 'batch_contexts/show'
      expect(rendered).to include('Jobs summary')
      expect(rendered).to include("<a href=\"/job_runs/#{job_run.id}\">#{job_run.id}</a>")
      expect(rendered).to include('<td>Discovery report</td>')
      expect(rendered).to include('<td>Waiting</td>')
    end
  end

  context 'when globus link deleted' do
    let(:bc) { create(:batch_context_with_deleted_output_dir, :with_deleted_globus_destination) }

    it 'does not render globus link' do
      render template: 'batch_contexts/show'
      expect(rendered).not_to include('Globus')
    end
  end
end
