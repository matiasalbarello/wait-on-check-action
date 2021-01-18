require "spec_helper"

describe GithubChecksVerifier do
  let(:service) { described_class.new("ref", "check_completed", "", "token", "0", "invoking_check", "10") }

  describe "#call" do
    before { allow(service).to receive(:wait_for_checks).and_raise(StandardError, "test error") }

    it "exit with status false if wait_for_checks fails" do
      expect { with_captured_stdout { service.call } }.to raise_error(SystemExit)
    end
  end

  describe "#wait_for_checks" do
    it "waits until all checks are completed" do
      cycles = 1 # simulates the method waiting for one cyecle
      allow(service).to receive(:all_checks_complete) do
        (cycles -= 1) && cycles < 0
      end

      all_successful_checks = load_json_sample("all_checks_successfully_completed.json")
      mock_http_success(with_json: all_successful_checks)
      output = with_captured_stdout{ service.wait_for_checks }

      expect(output).to include("The requested check isn't complete yet, will check back in #{service.wait} seconds...")
    end
  end

  describe "#all_checks_complete" do
    it "returns true if all checks are in status complete" do
      expect(service.all_checks_complete(
        [
          Check.new(name: "test", status: "completed", conclusion: "success"),
          Check.new(name: "test", status: "completed", conclusion: "failure")
        ]
      )).to be true
    end

    context "some checks (apart from the invoking one) are not complete" do
      it "false if some check still queued" do
        expect(service.all_checks_complete(
          [
            Check.new(name: "test", status: "completed", conclusion: "success"),
            Check.new(name: "test", status: "queued")
          ]
        )).to be false
      end

      it "false if some check is in progress" do
        expect(service.all_checks_complete(
          [
            Check.new(name: "test", status: "completed", conclusion: "success"),
            Check.new(name: "test", status: "in_progress")
          ]
        )).to be false
      end
    end
  end

  describe "#query_check_status" do
    it "parses and filters out the checks" do
      all_checks = load_json_sample("all_checks_results.json")
      mock_http_success(with_json: all_checks)
      allow(service).to receive(:parse_json_response).and_return(all_checks)
      allow(service).to receive(:filter_out_checks).with(all_checks)
      service.query_check_status

      expect(service).to have_received(:parse_json_response)
      expect(service).to have_received(:filter_out_checks)
    end
  end

  describe "#fail_if_requested_check_never_run" do
    it "raises an exception if check_name is not empty and all_checks is" do
      check_name = 'test'
      all_checks = []

      expect do
        service.fail_if_requested_check_never_run(all_checks)
      end.to raise_error(StandardError, "The requested check was never run against this ref, exiting...")
    end
  end

  describe "#fail_unless_all_success" do
    it "raises an exception if some check is not successful" do
      all_checks = [
        Check.new(name: "test", status: "complete", conclusion: "success"),
        Check.new(name: "test", status: "complete", conclusion: "failure")
      ]

      expect do
        service.fail_unless_all_success(all_checks)
      end.to raise_error(StandardError, "One or more checks were not successful, exiting...")
    end
  end

  describe "#show_checks_conclusion_message" do
    it "prints successful message to standard output" do
      checks = [Check.new(name: "check_completed", status: "completed", conclusion: "success")]
      output = with_captured_stdout{ service.show_checks_conclusion_message(checks) }

      expect(output).to include("check_completed: completed (success)")
    end
  end

  describe "#filter_out_checks" do
    it "filters out all but check_name" do
      checks = [
        Check.new(name: "check_name", status: "queued"),
        Check.new(name: "other_check", status: "queued")
      ]

      service = described_class.new("", "", "", "", "0", "", "10")
      service.check_name = "check_name"
      service.filter_out_checks(checks)
      expect(checks.map(&:name)).to all( eq "check_name" )
    end

    it "does not filter by check_name if it's empty" do
      checks = [
        Check.new(name: "check_name", status: "queued"),
        Check.new(name: "other_check", status: "queued")
      ]

      service = described_class.new("", "", "", "", "0", "", "10")
      allow(service).to receive(:apply_regexp_filter).with(checks).and_return(checks)
      service.filter_out_checks(checks)
      expect(checks.size).to eq 2
    end

    it "filters out the workflow_name" do
      checks = [
        Check.new(name: "workflow_name", status: "pending"),
        Check.new(name: "other_check", status: "queued")
      ]

      service = described_class.new("ref", "", "", "", "0", "", "10")
      service.workflow_name = "workflow_name"
      service.filter_out_checks(checks)
      expect(checks.map(&:name)).not_to include("workflow_name")
    end

    it "apply the regexp filter" do
      checks = [
        Check.new(name: "test", status: "pending"),
        Check.new(name: "test", status: "queued")
      ]
      allow(service).to receive(:apply_regexp_filter)
      service.filter_out_checks(checks)

      # only assert that the method is called. The functionality will be tested
      # on #apply_regexp_filter tests
      expect(service).to have_received(:apply_regexp_filter)
    end
  end

  describe "#apply_regexp_filter" do
    it "simple regexp" do
      checks = [
        Check.new(name: "check_name", status: "queued"),
        Check.new(name: "other_check", status: "queued")
      ]

      service.check_regexp = Regexp.new('._check')
      service.apply_regexp_filter(checks)

      expect(checks.map(&:name)).to include("other_check")
      expect(checks.map(&:name)).not_to include("check_name")
    end

    it "complex regexp" do

      checks = [
        Check.new(name: "test@example.com", status: "queued"),
        Check.new(name: "other_check", status: "queued")
      ]

      service.check_regexp = Regexp.new('\A[\w.+-]+@\w+\.\w+\z')
      service.apply_regexp_filter(checks)

      expect(checks.map(&:name)).not_to include("other_check")
      expect(checks.map(&:name)).to include("test@example.com")
    end
  end
end
