require "spec_helper"
require "travis/travis_yml_stats"

describe Travis::TravisYmlStats do
  let(:publisher) { mock("keen-publisher") }
  subject { described_class.store_stats(request, publisher) }
  let(:config) { {} }

  let(:request) do
    stub({
      config: config,
      payload: {
        "repository" => {}
      },
      repository_id: 123,
      event_type: "push",
      owner_id: 234,
      owner_type: "User",
      builds: [
        stub(matrix: [ stub, stub ])
      ]
    })
  end

  def requests_should_contain(opts)
    publisher.expects(:perform_async).with(has_entries(opts), anything, anything)
  end

  def deployments_should_contain(items)
    publisher.expects(:perform_async).with(anything, all_of(items.each {|i| includes(i)}), anything)
  end

  def notifications_should_contain(items)
    publisher.expects(:perform_async).with(anything, anything, all_of(items.each {|i| includes(i)}))
  end

  describe ".travis.yml language key" do
    context "when `language: ruby'" do
      before do
        request.config["language"] = "ruby"
      end

      it "sets the language key to 'ruby'" do
        requests_should_contain language: "ruby"

        subject
      end
    end

    context "when not specified" do
      it "sets the language key to nil" do
        requests_should_contain language: "default"

        subject
      end
    end

    context "when `language: [ 'ruby', 'python' ]'" do
      before do
        request.config["language"] = [ "ruby", "python" ]
      end

      it "sets the language key to 'invalid'" do
        requests_should_contain language: "invalid"

        subject
      end
    end

    context "when `language: objective c'" do
      before do
        request.config["language"] = "objective c"
      end

      it "retains the space" do
        requests_should_contain language: "objective c"

        subject
      end
    end
  end

  describe "repository language reported by GitHub" do
    context "Ruby" do
      before do
        request.payload["repository"]["language"] = "Ruby"
      end

      it "sets the github_language key to 'Ruby'" do
        requests_should_contain github_language: "Ruby"

        subject
      end
    end

    context "F#" do
      before do
        request.payload["repository"]["language"] = "F#"
      end

      it "sets the github_language key to 'F#'" do
        requests_should_contain github_language: "F#"

        subject
      end
    end

    context "no language reported" do
      before do
        request.payload["repository"]["language"] = nil
      end

      it "sets the github_language key to nil" do
        requests_should_contain github_language: nil

        subject
      end
    end
  end

  describe ".travis.yml ruby key" do
    context "when `ruby: 2.1.2'" do
      before do
        request.config["ruby"] = "2.1.2"
      end

      it "sets the language_version.ruby key to ['2.1.2']" do
        requests_should_contain language_version: { ruby: ["2.1.2"] }

        subject
      end
    end

    context "when `ruby: [ '2.1.2', '2.0.0' ]'" do
      before do
        request.config["ruby"] = %w[ 2.1.2 2.0.0 ]
      end

      it "sets the language_version.ruby key to ['2.0.0', '2.1.2']" do
        requests_should_contain language_version: { ruby: %w[2.0.0 2.1.2] }

        subject
      end
    end

    context "when `ruby: [ '2.1.2', 2.0 ]'" do
      before do
        request.config["ruby"] = [ "2.1.2", 2.0 ]
      end

      it "sets the language_version.ruby key to ['2.0', '2.1.2']" do
        requests_should_contain language_version: { ruby: %w[2.0 2.1.2] }

        subject
      end
    end
  end

  describe "sudo being used in a command" do
    context "sudo is used in a command" do
      before do
        request.config["before_install"] = "sudo apt-get update"
      end

      it "sets the uses_sudo key to true" do
        requests_should_contain uses_sudo: true

        subject
      end
    end

    context "sudo is not used in any commands" do
      it "sets the uses_sudo key to false" do
        requests_should_contain uses_sudo: false

        subject
      end
    end
  end

  describe "apt-get being used in a command" do
    context "apt-get is used in a command" do
      before do
        request.config["before_install"] = "sudo apt-get update"
      end

      it "sets the uses_apt_get key to true" do
        requests_should_contain uses_apt_get: true

        subject
      end
    end

    context "apt-get is not used in any commands" do
      it "sets the uses_apt_get key to false" do
        requests_should_contain uses_apt_get: false

        subject
      end
    end
  end

  describe "a push" do
    before do
      request.stubs(:event_type).returns("push")
    end

    it "sets the event_type to 'push'" do
      requests_should_contain event_type: "push"

      subject
    end
  end

  describe "a pull_request" do
    before do
      request.stubs(:event_type).returns("pull_request")
    end

    it "sets the event_type to 'pull_request'" do
      requests_should_contain event_type: "pull_request"

      subject
    end
  end

  describe "a build with two jobs" do
    it "sets the matrix_size to 2" do
      requests_should_contain matrix_size: 2

      subject
    end
  end

  it "owner_type and owner_id are set" do
    requests_should_contain owner_id: 234, owner_type: "User", owner: ["User", 234]

    subject
  end

  describe "a request without 'dist' key" do
    it "sets the dist_name key to 'default'" do
      requests_should_contain dist_name: 'default'

      subject
    end
  end

  describe "a request with 'dist' key" do
    before do
      request.config['dist'] = 'trusty'
    end

    it "sets the dist_name key to 'trusty'" do
      requests_should_contain dist_name: 'trusty'

      subject
    end
  end

  describe "a request without 'group' key" do
    it "sets the group_name key to 'default'" do
      requests_should_contain group_name: 'default'

      subject
    end
  end

  describe "a request with 'group' key" do
    before do
      request.config['group'] = 'dev'
    end

    it "sets the group_name key to 'dev'" do
      requests_should_contain group_name: 'dev'

      subject
    end
  end

  context "when payload contains a single deployment provider" do
    let(:config) { { "deploy" => { "provider" => "s3" } } }

    it "reports deployment count correctly" do
      deployments_should_contain( [{:provider => 's3', :repository_id => 123}] )
      subject
    end
  end

  context "when payload contains multiple deployment providers" do
    let(:config) { { "deploy" => [ { "provider" => "s3" }, { "provider" => "npm" } ] } }

    it "reports deployment count correctly" do
      deployments_should_contain( [{:provider => 's3', :repository_id => 123}, {:provider => 'npm', :repository_id => 123}] )
      subject
    end
  end

  context "when payload contains multiple deployment providers of the same type" do
    let(:config) { { "deploy" => [ { "provider" => "s3" }, { "provider" => "s3" } ] } }

    it "reports deployment count correctly" do
      deployments_should_contain( [{:provider => 's3', :repository_id => 123}] )
      subject
    end
  end

  context "when payload contains notifications" do
    let(:config) { { "notifications" => { "irc" => "chat.freenode.net#travis" } } }

    it "reports deployment count correctly" do
      notifications_should_contain( [{:notifier => 'irc', :repository_id => 123}] )
      subject
    end
  end
end
