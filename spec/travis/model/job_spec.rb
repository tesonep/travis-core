require 'spec_helper'

describe Job do
  include Support::ActiveRecord

  describe '.result' do
    it 'returns 1 for failed builds' do
      job = Factory.build(:test, state: :failed)
      expect(job.result).to eq(1)
    end

    it 'returns 0 for passed builds' do
      job = Factory.build(:test, state: :passed)
      expect(job.result).to eq(0)
    end
  end

  describe ".queued" do
    let(:jobs) { [Factory.create(:test), Factory.create(:test), Factory.create(:test)] }

    it "returns jobs that are created but not started or finished" do
      jobs.first.start!
      jobs.third.start!
      jobs.third.finish!(state: 'passed')

      expect(Job.queued).to include(jobs.second)
      expect(Job.queued).not_to include(jobs.first)
      expect(Job.queued).not_to include(jobs.third)
    end
  end

  describe 'before_create' do
    let(:job) { Job::Test.create!(owner: Factory(:user), repository: Factory(:repository), commit: Factory(:commit), source: Factory(:build)) }

    before :each do
      Job::Test.any_instance.stubs(:enqueueable?).returns(false) # prevent jobs to enqueue themselves on create
    end

    it 'instantiates the log' do
      expect(job.reload.log).to be_instance_of(Log)
    end

    it 'sets the state attribute' do
      expect(job.reload).to be_created
    end

    it 'sets the queue attribute' do
      expect(job.reload.queue).to eq('builds.linux')
    end
  end

  describe 'duration' do
    it 'returns nil if both started_at is not populated' do
      job = Job.new(finished_at: Time.now)
      expect(job.duration).to be_nil
    end

    it 'returns nil if both finished_at is not populated' do
      job = Job.new(started_at: Time.now)
      expect(job.duration).to be_nil
    end

    it 'returns the duration if both started_at and finished_at are populated' do
      job = Job.new(started_at: 20.seconds.ago, finished_at: 10.seconds.ago)
      expect(job.duration).to eq(10)
    end
  end

  describe 'obfuscated config' do
    it 'handles nil env' do
      job = Job.new(repository: Factory(:repository))
      job.config = { rvm: '1.8.7', env: nil }

      expect(job.obfuscated_config).to eq({
        rvm: '1.8.7',
        env: nil
      })
    end

    it 'leaves regular vars untouched' do
      job = Job.new(repository: Factory(:repository))
      job.expects(:secure_env_enabled?).at_least_once.returns(true)
      job.config = { rvm: '1.8.7', env: 'FOO=foo' }

      expect(job.obfuscated_config).to eq({
        rvm: '1.8.7',
        env: 'FOO=foo'
      })
    end

    it 'obfuscates env vars' do
      job = Job.new(repository: Factory(:repository))
      job.expects(:secure_env_enabled?).at_least_once.returns(true)
      config = { rvm: '1.8.7',
                 env: [job.repository.key.secure.encrypt('BAR=barbaz'), 'FOO=foo']
               }
      job.config = config

      expect(job.obfuscated_config).to eq({
        rvm: '1.8.7',
        env: 'BAR=[secure] FOO=foo'
      })
    end

    it 'normalizes env vars which are hashes to strings' do
      job = Job.new(repository: Factory(:repository))
      job.expects(:secure_env_enabled?).at_least_once.returns(true)

      config = { rvm: '1.8.7',
                 env: [{FOO: 'bar', BAR: 'baz'},
                          job.repository.key.secure.encrypt('BAR=barbaz')]
               }
      job.config = config

      expect(job.obfuscated_config).to eq({
        rvm: '1.8.7',
        env: 'FOO=bar BAR=baz BAR=[secure]'
      })
    end

    it 'removes addons config if it is not a hash' do
      job = Job.new(repository: Factory(:repository))
      config = { rvm: '1.8.7',
                 addons: "foo",
               }
      job.config = config

      expect(job.obfuscated_config).to eq({
        rvm: '1.8.7'
      })
    end

    it 'removes addons config which is not whitelisted' do
      job = Job.new(repository: Factory(:repository))
      config = { rvm: '1.8.7',
                 addons: { sauce_connect: true, firefox: '22.0' },
               }
      job.config = config

      expect(job.obfuscated_config).to eq({
        rvm: '1.8.7',
        addons: {
          firefox: '22.0'
        }
      })
    end

    it 'removes source key' do
      job = Job.new(repository: Factory(:repository))
      config = { rvm: '1.8.7',
                 source_key: '1234'
               }
      job.config = config

      expect(job.obfuscated_config).to eq({
        rvm: '1.8.7',
      })
    end
    context 'when job has secure env disabled' do
      let :job do
        job = Job.new(repository: Factory(:repository))
        job.expects(:secure_env_enabled?).returns(false).at_least_once
        job
      end

      it 'removes secure env vars' do
        config = { rvm: '1.8.7',
                   env: [job.repository.key.secure.encrypt('BAR=barbaz'), 'FOO=foo']
                 }
        job.config = config

        expect(job.obfuscated_config).to eq({
          rvm: '1.8.7',
          env: 'FOO=foo'
        })
      end

      it 'works even if it removes all env vars' do
        config = { rvm: '1.8.7',
                   env: [job.repository.key.secure.encrypt('BAR=barbaz')]
                 }
        job.config = config

        expect(job.obfuscated_config).to eq({
          rvm: '1.8.7',
          env: nil
        })
      end

      it 'normalizes env vars which are hashes to strings' do
        config = { rvm: '1.8.7',
                   env: [{FOO: 'bar', BAR: 'baz'},
                            job.repository.key.secure.encrypt('BAR=barbaz')]
                 }
        job.config = config

        expect(job.obfuscated_config).to eq({
          rvm: '1.8.7',
          env: 'FOO=bar BAR=baz'
        })
      end
    end
  end

  describe '#pull_request?' do
    it 'is delegated to commit' do
      commit = Commit.new
      commit.expects(:pull_request?).returns(true)

      job = Job.new
      job.commit = commit
      expect(job.pull_request?).to be_truthy
    end
  end

  describe 'decrypted config' do
    it 'handles nil env' do
      job = Job.new(repository: Factory(:repository))
      job.config = { rvm: '1.8.7', env: nil, global_env: nil }

      expect(job.decrypted_config).to eq({
        rvm: '1.8.7',
        env: nil,
        global_env: nil
      })
    end

    it 'normalizes env vars which are hashes to strings' do
      job = Job.new(repository: Factory(:repository))
      job.expects(:secure_env_enabled?).at_least_once.returns(true)

      config = { rvm: '1.8.7',
                 env: [{FOO: 'bar', BAR: 'baz'},
                          job.repository.key.secure.encrypt('BAR=barbaz')],
                 global_env: [{FOO: 'foo', BAR: 'bar'},
                          job.repository.key.secure.encrypt('BAZ=baz')]
               }
      job.config = config

      expect(job.decrypted_config).to eq({
        rvm: '1.8.7',
        env: ["FOO=bar BAR=baz", "SECURE BAR=barbaz"],
        global_env: ["FOO=foo BAR=bar", "SECURE BAZ=baz"]
      })
    end

    it 'does not change original config' do
      job = Job.new(repository: Factory(:repository))
      job.expects(:secure_env_enabled?).at_least_once.returns(true)

      config = {
                 env: [{secure: 'invalid'}],
                 global_env: [{secure: 'invalid'}]
               }
      job.config = config

      job.decrypted_config
      expect(job.config).to eq({
        env: [{ secure: 'invalid' }],
        global_env: [{ secure: 'invalid' }]
      })
    end

    it 'leaves regular vars untouched' do
      job = Job.new(repository: Factory(:repository))
      job.expects(:secure_env_enabled?).returns(true).at_least_once
      job.config = { rvm: '1.8.7', env: 'FOO=foo', global_env: 'BAR=bar' }

      expect(job.decrypted_config).to eq({
        rvm: '1.8.7',
        env: ['FOO=foo'],
        global_env: ['BAR=bar']
      })
    end

    context 'when secure env is not enabled' do
      let :job do
        job = Job.new(repository: Factory(:repository))
        job.expects(:secure_env_enabled?).returns(false).at_least_once
        job
      end

      it 'removes secure env vars' do
        config = { rvm: '1.8.7',
                   env: [job.repository.key.secure.encrypt('BAR=barbaz'), 'FOO=foo'],
                   global_env: [job.repository.key.secure.encrypt('BAR=barbaz'), 'BAR=bar']
                 }
        job.config = config

        expect(job.decrypted_config).to eq({
          rvm: '1.8.7',
          env: ['FOO=foo'],
          global_env: ['BAR=bar']
        })
      end

      it 'removes only secured env vars' do
        config = { rvm: '1.8.7',
                   env: [job.repository.key.secure.encrypt('BAR=barbaz'), 'FOO=foo']
                 }
        job.config = config

        expect(job.decrypted_config).to eq({
          rvm: '1.8.7',
          env: ['FOO=foo']
        })
      end
    end

    context 'when addons are disabled' do
      let :job do
        job = Job.new(repository: Factory(:repository))
        job.expects(:addons_enabled?).returns(false).at_least_once
        job
      end

      it 'removes addons if it is not a hash' do
        config = { rvm: '1.8.7',
                   addons: []
                 }
        job.config = config

        expect(job.decrypted_config).to eq({
          rvm: '1.8.7'
        })
      end

      it 'removes addons items which are not whitelisted' do
        config = { rvm: '1.8.7',
                   addons: {
                     sauce_connect: {
                       username: 'johndoe',
                       access_key: job.repository.key.secure.encrypt('foobar')
                     },
                     firefox: '22.0',
                     postgresql: '9.3',
                     hosts: ["travis.dev"]
                   }
                 }
        job.config = config

        expect(job.decrypted_config).to eq({
          rvm: '1.8.7',
          addons: {
            firefox: '22.0',
            postgresql: '9.3',
            hosts: ["travis.dev"]
          }
        })
      end
    end

    context 'when job has secure env enabled' do
      let :job do
        job = Job.new(repository: Factory(:repository))
        job.expects(:secure_env_enabled?).returns(true).at_least_once
        job
      end

      it 'decrypts env vars' do
        config = { rvm: '1.8.7',
                   env: job.repository.key.secure.encrypt('BAR=barbaz'),
                   global_env: job.repository.key.secure.encrypt('BAR=bazbar')
                 }
        job.config = config

        expect(job.decrypted_config).to eq({
          rvm: '1.8.7',
          env: ['SECURE BAR=barbaz'],
          global_env: ['SECURE BAR=bazbar']
        })
      end

      it 'decrypts only secure env vars' do
        config = { rvm: '1.8.7',
                   env: [job.repository.key.secure.encrypt('BAR=bar'), 'FOO=foo'],
                   global_env: [job.repository.key.secure.encrypt('BAZ=baz'), 'QUX=qux']
                 }
        job.config = config

        expect(job.decrypted_config).to eq({
          rvm: '1.8.7',
          env: ['SECURE BAR=bar', 'FOO=foo'],
          global_env: ['SECURE BAZ=baz', 'QUX=qux']
        })
      end
    end

    context 'when job has addons enabled' do
      let :job do
        job = Job.new(repository: Factory(:repository))
        job.expects(:addons_enabled?).returns(true).at_least_once
        job
      end

      it 'decrypts addons config' do
        config = { rvm: '1.8.7',
                   addons: {
                     sauce_connect: {
                       username: 'johndoe',
                       access_key: job.repository.key.secure.encrypt('foobar')
                     }
                   }
                 }
        job.config = config

        expect(job.decrypted_config).to eq({
          rvm: '1.8.7',
          addons: {
            sauce_connect: {
              username: 'johndoe',
              access_key: 'foobar'
            }
          }
        })
      end

      it 'decrypts deploy addon config' do
        config = { rvm: '1.8.7',
                   deploy: { foo: job.repository.key.secure.encrypt('foobar') }
                 }
        job.config = config

        expect(job.decrypted_config).to eq({
          rvm: '1.8.7',
          addons: {
            deploy: { foo: 'foobar' }
          }
        })
      end
    end
  end

  describe 'log_content=' do
    let(:job) { Job::Test.create!(owner: Factory(:user), repository: Factory(:repository), commit: Factory(:commit), source: Factory(:build), log: Factory(:log)) }

    it 'sets the log content' do
      job.log_content = 'Hello, world'
      expect(job.log.content).to eq('Hello, world')
    end

    it 'blanks out any old log content' do
      job.log_content = 'foo'
      job.log_content = 'bar'
      expect(job.log.content).to eq('bar')
    end
  end
end
