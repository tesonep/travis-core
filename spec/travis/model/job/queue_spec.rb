require 'spec_helper'

describe 'Job::Queue' do
  def queue(*args)
    Job::Queue.new(*args)
  end

  before do
    Travis.config.queues = [
      { :queue => 'builds.rails', :slug => 'rails/rails' },
      { :queue => 'builds.mac_osx', :os => 'osx' },
      { :queue => 'builds.docker', :sudo => false },
      { :queue => 'builds.education', :education => true },
      { :queue => 'builds.cloudfoundry', :owner => 'cloudfoundry' },
      { :queue => 'builds.clojure', :language => 'clojure' },
      { :queue => 'builds.erlang', :language => 'erlang' },
    ]
    Job::Queue.instance_variable_set(:@queues, nil)
    Job::Queue.instance_variable_set(:@default, nil)
    Travis::Features.stubs(:owner_active?).returns(true)
  end

  after do
    Travis.config.default_queue = 'builds.linux'
  end

  it 'returns builds.linux as the default queue' do
    expect(Job::Queue.default.name).to eq('builds.linux')
  end

  it 'returns builds.common as the default queue if configured to in Travis.config' do
    Travis.config.default_queue = 'builds.common'
    expect(Job::Queue.default.name).to eq('builds.common')
  end

  describe 'Queue.for' do
    it 'returns the default build queue when neither slug or language match the given configuration hash' do
      job = stub('job', :config => {}, :repository => stub('repository', :owner_name => 'travis-ci', :name => 'travis-ci', :owner => stub))
      expect(Job::Queue.for(job).name).to eq('builds.linux')
    end

    it 'returns the queue when slug matches the given configuration hash' do
      job = stub('job', :config => {}, :repository => stub('repository', :owner_name => 'rails', :name => 'rails', :owner => stub))
      expect(Job::Queue.for(job).name).to eq('builds.rails')
    end

    it 'returns the queue when language matches the given configuration hash' do
      job = stub('job', :config => { :language => 'clojure' }, :repository => stub('repository', :owner_name => 'travis-ci', :name => 'travis-ci', :owner => stub))
      expect(Job::Queue.for(job).name).to eq('builds.clojure')
    end

    it 'returns the queue when the owner matches the given configuration hash' do
      job = stub('job', :config => {}, :repository => stub('repository', :owner_name => 'cloudfoundry', :name => 'bosh', :owner => stub))
      expect(Job::Queue.for(job).name).to eq('builds.cloudfoundry')
    end

    it 'returns the queue when sudo requirements matches the given configuration hash' do
      job = stub('job', :config => { sudo: false }, :repository => stub('repository', :owner_name => 'markronson', :name => 'recordcollection', :owner => stub))
      expect(Job::Queue.for(job).name).to eq('builds.docker')
    end

    it 'returns the queue when education requirements matches the given configuration hash' do
      Travis::Github::Education.stubs(:active?).returns(true)
      owner = stub('owner', :education => true)
      job = stub('job', :config => { }, :repository => stub('repository', :owner_name => 'markronson', :name => 'recordcollection', :owner => owner))
      expect(Job::Queue.for(job).name).to eq('builds.education')
    end

    it 'does not return education queue if feature flag is disabled' do
      Travis::Github::Education.stubs(:active?).returns(false)
      owner = stub('owner', :education => true)
      job = stub('job', :config => { }, :repository => stub('repository', :owner_name => 'markronson', :name => 'recordcollection', :owner => owner))
      expect(Job::Queue.for(job).name).to eq('builds.linux')
    end

    it 'returns the queue when education requirements matches, ignoring configuration hash' do
      Travis::Github::Education.stubs(:active?).returns(true)
      owner = stub('owner', :education => true)
      job = stub('job', :config => { :os => 'osx' }, :repository => stub('repository', :owner_name => 'markronson', :name => 'recordcollection', :owner => owner))
      expect(Job::Queue.for(job).name).to eq('builds.education')
    end

    it 'handles language being passed as an array gracefully' do
      job = stub('job', :config => { :language => ['clojure'] }, :repository => stub('repository', :owner_name => 'travis-ci', :name => 'travis-ci', :owner => stub))
      expect(Job::Queue.for(job).name).to eq('builds.clojure')
    end

    context 'when "os" value matches the given configuration hash' do
      it 'returns the matching queue' do
        job = stub('job', :config => { :os => 'osx'}, :repository => stub('travis-core', :owner_name => 'travis-ci', :name => 'bosh', :owner => stub))
        expect(Job::Queue.for(job).name).to eq('builds.mac_osx')
      end

      it 'returns the matching queue when language is also given' do
        job = stub('job', :config => {:language => 'clojure', :os => 'osx'}, :repository => stub('travis-core', :owner_name => 'travis-ci', :name => 'bosh', :owner => stub))
        expect(Job::Queue.for(job).name).to eq('builds.mac_osx')
      end
    end
  end

  context 'when "sudo" value matches the given configuration hash' do
    context 'when the repository owner is feature flagged' do
      it 'returns the matching queue' do
        job = stub('job', config: { sudo: false }, repository: stub('travis-core', owner_name: 'travis-ci', name: 'travis-core', owner: stub))
        expect(Job::Queue.for(job).name).to eq('builds.docker')
      end

      it 'returns the matching queue when language is also given' do
        job = stub('job', config: { language: 'clojure', sudo: false }, repository: stub('travis-core', owner_name: 'travis-ci', name: 'travis-core', owner: stub))
        expect(Job::Queue.for(job).name).to eq('builds.docker')
      end
    end

    context 'when the repository owner is not feature flagged' do
      before :each do
        Travis::Features.stubs(:owner_active?).returns(false)
      end

      it 'returns the matching queue' do
        job = stub('job', config: { sudo: false }, repository: stub('travis-core', owner_name: 'travis-ci', name: 'travis-core', owner: stub))
        expect(Job::Queue.for(job).name).to eq('builds.linux')
      end

      it 'returns the matching queue when language is also given' do
        job = stub('job', config: { language: 'clojure', sudo: false }, repository: stub('travis-core', owner_name: 'travis-ci', name: 'travis-core', owner: stub))
        expect(Job::Queue.for(job).name).to eq('builds.clojure')
      end
    end
  end

  describe 'Queue.queues' do
    it 'returns an array of Queues for the config hash' do
      rails, os, docker, edu, cloudfoundry, clojure, erlang = Job::Queue.send(:queues)

      expect(rails.name).to eq('builds.rails')
      expect(rails.slug).to eq('rails/rails')

      expect(docker.name).to eq('builds.docker')
      expect(docker.sudo).to eq(false)

      expect(edu.name).to eq('builds.education')
      expect(edu.education).to eq(true)

      expect(cloudfoundry.name).to eq('builds.cloudfoundry')
      expect(cloudfoundry.owner).to eq('cloudfoundry')

      expect(clojure.name).to eq('builds.clojure')
      expect(clojure.language).to eq('clojure')
    end
  end

  describe 'matches?' do
    it "returns false when neither of slug or language match" do
      queue = queue('builds.linux',  nil, nil, nil)
      expect(queue.send(:matches?, 'foo', 'foo/bar', 'COBOL')).to be_falsey
    end

    it "returns true when the given owner matches" do
      queue = queue('builds.cloudfoundry', nil, 'cloudfoundry', nil)
      expect(queue.send(:matches?, 'cloudfoundry', 'bosh', nil)).to be_truthy
    end

    it "returns true when the given slug matches" do
      queue = queue('builds.rails', 'rails/rails', nil, nil)
      expect(queue.send(:matches?, 'rails', 'rails', nil)).to be_truthy
    end

    it "returns true when the given language matches" do
      queue = queue('builds.linux', nil, nil, 'clojure')
      expect(queue.send(:matches?, nil, nil, 'clojure')).to be_truthy
    end

    it 'returns true when os is missing' do
      queue = queue('builds.linux', nil, nil, 'clojure', nil)
      expect(queue.send(:matches?, nil, nil, 'clojure', nil)).to be_truthy
    end

    it 'returns true when sudo is false' do
      queue = queue('builds.docker', nil, nil, nil, nil, false)
      expect(queue.send(:matches?, nil, nil, nil, nil, false)).to be_truthy
    end

    it 'returns false when sudo is true' do
      queue = queue('builds.docker', nil, nil, nil, nil, false)
      expect(queue.send(:matches?, nil, nil, nil, nil, true)).to be_falsey
    end

    it 'returns false when sudo is nil' do
      queue = queue('builds.docker', nil, nil, nil, nil, false)
      expect(queue.send(:matches?, nil, nil, nil, nil, nil)).to be_falsey
    end
  end
end
