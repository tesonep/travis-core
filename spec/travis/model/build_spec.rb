require 'spec_helper'

describe Build do
  include Support::ActiveRecord

  let(:repository) { Factory(:repository) }

  it 'caches matrix ids' do
    build = Factory.create(:build, config: { rvm: ['1.9.3', '2.0.0'] })
    expect(build.cached_matrix_ids).to eq(build.matrix_ids)
  end

  it 'returns nil if cached_matrix_ids are not set' do
    build = Factory.create(:build)
    build.update_column(:cached_matrix_ids, nil)
    expect(build.reload.cached_matrix_ids).to be_nil
  end

  it 'is cancelable if at least one job is cancelable' do
    jobs = [Factory.build(:test), Factory.build(:test)]
    jobs.first.stubs(:cancelable?).returns(true)
    jobs.second.stubs(:cancelable?).returns(false)

    build = Factory.build(:build, matrix: jobs)
    expect(build).to be_cancelable
  end

  it 'is not cancelable if none of the jobs are cancelable' do
    jobs = [Factory.build(:test), Factory.build(:test)]
    jobs.first.stubs(:cancelable?).returns(false)
    jobs.second.stubs(:cancelable?).returns(false)

    build = Factory.build(:build, matrix: jobs)
    expect(build).not_to be_cancelable
  end

  describe '#secure_env_enabled?' do
    it 'returns true if we\'re not dealing with pull request' do
      build = Factory.build(:build)
      build.stubs(:pull_request?).returns(false)
      expect(build.secure_env_enabled?).to be_truthy
    end

    it 'returns true if pull request is from the same repository' do
      build = Factory.build(:build)
      build.stubs(:pull_request?).returns(true)
      build.stubs(:same_repo_pull_request?).returns(true)
      expect(build.secure_env_enabled?).to be_truthy
    end

    it 'returns false if pull request is not from the same repository' do
      build = Factory.build(:build)
      build.stubs(:pull_request?).returns(true)
      build.stubs(:same_repo_pull_request?).returns(false)
      expect(build.secure_env_enabled?).to be_falsey
    end
  end

  describe 'class methods' do
    describe 'recent' do
      it 'returns recent builds ordered by started time descending' do
        Factory(:build, state: 'passed', started_at: 2.second.ago)
        Factory(:build, state: 'started', started_at: 1.second.ago)
        Factory(:build, state: 'created', started_at: nil)

        expect(Build.recent.all.map(&:state)).to eq(['started', 'passed'])
      end
    end

    describe 'was_started' do
      it 'returns builds that are either started or finished' do
        Factory(:build, state: 'passed')
        Factory(:build, state: 'started')
        Factory(:build, state: 'created')

        expect(Build.was_started.map(&:state).sort).to eq(['passed', 'started'])
      end
    end

    describe 'on_branch' do
      it 'returns builds that are on any of the given branches' do
        Factory(:build, commit: Factory(:commit, branch: 'master'))
        Factory(:build, commit: Factory(:commit, branch: 'develop'))
        Factory(:build, commit: Factory(:commit, branch: 'feature'))

        expect(Build.on_branch('master,develop').map(&:commit).map(&:branch).sort).to eq(['develop', 'master'])
      end

      it 'does not include pull requests' do
        Factory(:build, commit: Factory(:commit, branch: 'no-pull'), request: Factory(:request, event_type: 'pull_request'))
        Factory(:build, commit: Factory(:commit, branch: 'no-pull'), request: Factory(:request, event_type: 'push'))
        expect(Build.on_branch('no-pull').count).to eq(1)
      end
    end

    describe 'older_than' do
      before do
        5.times { |i| Factory(:build, number: i) }
        Build.stubs(:per_page).returns(2)
      end

      context "when a Build is passed in" do
        subject { Build.older_than(Build.new(number: 3)) }

        it "should limit the results" do
          expect(subject.size).to eq(2)
        end

        it "should return older than the passed build" do
          expect(subject.map(&:number)).to eq(['2', '1'])
        end
      end

      context "when a number is passed in" do
        subject { Build.older_than(3) }

        it "should limit the results" do
          expect(subject.size).to eq(2)
        end

        it "should return older than the passed build" do
          expect(subject.map(&:number)).to eq(['2', '1'])
        end
      end

      context "when not passing a build" do
        subject { Build.older_than() }

        it "should limit the results" do
          expect(subject.size).to eq(2)
        end
      end
    end

    describe 'paged' do
      it 'limits the results to the `per_page` value' do
        3.times { Factory(:build) }
        Build.stubs(:per_page).returns(1)

        expect(Build.descending.paged({}).size).to eq(1)
      end

      it 'uses an offset' do
        3.times { |i| Factory(:build) }
        Build.stubs(:per_page).returns(1)

        builds = Build.descending.paged({page: 2})
        expect(builds.size).to eq(1)
        expect(builds.first.number).to eq('2')
      end
    end

    describe 'next_number' do
      it 'returns the next build number' do
        1.upto(3) do |number|
          Factory(:build, repository: repository, number: number)
          expect(repository.builds.next_number).to eq(number + 1)
        end
      end
    end

    describe 'pushes' do
      before do
        Factory(:build)
        Factory(:build, request: Factory(:request, event_type: 'pull_request'))
      end

      it "returns only builds which have Requests with an event_type of push" do
        expect(Build.pushes.all.count).to eq(1)
      end
    end

    describe 'pull_requests' do
      before do
        Factory(:build)
        Factory(:build, request: Factory(:request, event_type: 'pull_request'))
      end

      it "returns only builds which have Requests with an event_type of pull_request" do
        expect(Build.pull_requests.all.count).to eq(1)
      end
    end
  end

  describe 'creation' do
    describe 'previous_state' do
      it 'is set to the last finished build state on the same branch' do
        Factory(:build, state: 'failed')
        expect(Factory(:build).reload.previous_state).to eq('failed')
      end

      it 'is set to the last finished build state on the same branch (disregards non-finished builds)' do
        Factory(:build, state: 'failed')
        Factory(:build, state: 'started')
        expect(Factory(:build).reload.previous_state).to eq('failed')
      end

      it 'is set to the last finished build state on the same branch (disregards other branches)' do
        Factory(:build, state: 'failed')
        Factory(:build, state: 'passed', commit: Factory(:commit, branch: 'something'))
        expect(Factory(:build).reload.previous_state).to eq('failed')
      end
    end
  end

  describe 'instance methods' do
    it 'sets its number to the next build number on creation' do
      1.upto(3) do |number|
        expect(Factory(:build).reload.number).to eq(number.to_s)
      end
    end

    it 'sets previous_state to nil if no last build exists on the same branch' do
      build = Factory(:build, commit: Factory(:commit, branch: 'master'))
      expect(build.reload.previous_state).to eq(nil)
    end

    it 'sets previous_state to the result of the last build on the same branch if exists' do
      build = Factory(:build, state: :canceled, commit: Factory(:commit, branch: 'master'))
      build = Factory(:build, commit: Factory(:commit, branch: 'master'))
      expect(build.reload.previous_state).to eq('canceled')
    end

    describe 'config' do
      it 'defaults to a hash with language and os set' do
        expect(Build.new.config).to eq({ language: 'ruby', os: 'linux' })
      end

      it 'deep_symbolizes keys on write' do
        build = Factory(:build, config: { 'foo' => { 'bar' => 'bar' } })
        expect(build.config[:foo][:bar]).to eq('bar')
      end
    end

    describe :pending? do
      it 'returns true if the build is finished' do
        build = Factory(:build, state: :finished)
        expect(build.pending?).to be_falsey
      end

      it 'returns true if the build is not finished' do
        build = Factory(:build, state: :started)
        expect(build.pending?).to be_truthy
      end
    end

    describe :passed? do
      it 'passed? returns true if state equals :passed' do
        build = Factory(:build, state: :passed)
        expect(build.passed?).to be_truthy
      end

      it 'passed? returns true if result does not equal :passed' do
        build = Factory(:build, state: :failed)
        expect(build.passed?).to be_falsey
      end
    end

    describe :color do
      it 'returns "green" if the build has passed' do
        build = Factory(:build, state: :passed)
        expect(build.color).to eq('green')
      end

      it 'returns "red" if the build has failed' do
        build = Factory(:build, state: :failed)
        expect(build.color).to eq('red')
      end

      it 'returns "yellow" if the build is pending' do
        build = Factory(:build, state: :started)
        expect(build.color).to eq('yellow')
      end
    end

    it 'saves event_type before create' do
      build = Factory(:build,  request: Factory(:request, event_type: 'pull_request'))
      expect(build.event_type).to eq('pull_request')

      build = Factory(:build,  request: Factory(:request, event_type: 'push'))
      expect(build.event_type).to eq('push')
    end

    it 'saves pull_request_title before create' do
      payload = { 'pull_request' => { 'title' => 'A pull request' } }
      build = Factory(:build,  request: Factory(:request, event_type: 'pull_request', payload: payload))
      expect(build.pull_request_title).to eq('A pull request')
    end

    it 'saves branch before create' do
      build = Factory(:build,  commit: Factory(:commit, branch: 'development'))
      expect(build.branch).to eq('development')
    end

    describe 'reset' do
      let(:build) { Factory(:build, state: 'finished') }

      before :each do
        build.matrix.each { |job| job.stubs(:reset) }
      end

      it 'sets the state to :created' do
        build.reset
        expect(build.state).to eq(:created)
      end

      it 'resets related attributes' do
        build.reset
        expect(build.duration).to be_nil
        expect(build.finished_at).to be_nil
      end

      it 'resets each job if :reset_matrix is given' do
        build.matrix.each { |job| job.expects(:reset) }
        build.reset(reset_matrix: true)
      end

      it 'does not reset jobs if :reset_matrix is not given' do
        build.matrix.each { |job| job.expects(:reset).never }
        build.reset
      end

      it 'notifies obsevers' do
        Travis::Event.expects(:dispatch).with('build:created', build)
        build.reset
      end
    end
  end
end
