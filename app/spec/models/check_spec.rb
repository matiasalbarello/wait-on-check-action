require "spec_helper"

describe Check do
  let(:successful_check) { described_class.new(name: "test", status: "completed", conclusion: "success") }
  let(:failing_check) { described_class.new(name: "test", status: "completed", conclusion: "failure") }
  let(:queued_check) { described_class.new(name: "test", status: "queued") }
  let(:in_progress_check) { described_class.new(name: "test", status: "in_progress") }

  describe "#success?" do
    it "is true if conclusion is success" do
      expect(successful_check).to be_success
    end

    it "is false if conclusion is not success" do
      expect(failing_check).not_to be_success
    end
  end

  describe "#conclusion_message" do
    it "shows the name, status and conclusion of checks" do
      expect(successful_check.conclusion_message).to eq("test: completed (success)")
      expect(failing_check.conclusion_message).to eq("test: completed (failure)")
      expect(queued_check.conclusion_message).to eq("test: queued ()")
      expect(in_progress_check.conclusion_message).to eq("test: in_progress ()")
    end
  end

  describe "status check" do
    it "responds to any method with question mark (?)" do
      expect(successful_check).not_to respond_to(:foo?)
      expect(successful_check.foo?).to eq false # it's state is not "foo"
    end

    it "completed? is true if the check is completed" do
      expect(successful_check.completed?).to eq true # it's state is not "foo"
    end

  end
end
