require "spec_helper"

describe "entrypoint" do
  it "calls the GithubChecksVerifier service" do
    service = instance_double(GithubChecksVerifier, call: true)
    allow(GithubChecksVerifier).to receive(:new).and_return(service)
    require_relative "../../entrypoint.rb"
    expect(service).to have_received(:call)

  end
end
