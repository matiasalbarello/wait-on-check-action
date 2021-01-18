# frozen_string_literal: true
require_relative "./application_service"
require_relative "../models/check"
require "net/http"
require "uri"
require "json"

class GithubChecksVerifier < ApplicationService
  attr_accessor :check_name, :check_regexp, :token, :wait, :workflow_name, :github_api_uri, :consumed_time_seconds

  def call
    wait_for_checks
  rescue StandardError => e
    puts e.message
    exit(false)
  end

  # check_name is the name of the "job" key in a workflow, or the full name if the "name" key
  # is provided for job. Probably, the "name" key should be kept empty to keep things short
  def initialize(ref, check_name, check_regexp, token, wait, workflow_name)
    @consumed_time_seconds = 0
    @check_name = check_name
    @check_regexp = Regexp.new(check_regexp)
    @token = token
    @wait = wait.to_i
    @workflow_name = workflow_name
    @github_api_uri = "https://api.github.com/repos/#{ENV["GITHUB_REPOSITORY"]}/commits/#{ref}/check-runs"
  end

  def query_check_status
    uri = URI.parse(github_api_uri)
    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/vnd.github.antiope-preview+json"
    token.empty? || request["Authorization"] = "token #{token}"
    req_options = {
      use_ssl: uri.scheme == "https"
    }
    response = Net::HTTP.start(uri.hostname, uri.port, req_options) { |http|
      http.request(request)
    }
    checks = parse_json_response(response.body)
    filter_out_checks(checks)
  end

  def parse_json_response(json)
    check_runs = JSON.parse(json)["check_runs"]

    check_runs.map do |check|
      Check.new(
        name: check['name'],
        status: check['status'],
        conclusion: check['conclusion']
      )
    end
  end

  def apply_regexp_filter(checks)
    checks.select!{ |check| check.name[check_regexp] }
  end

  def filter_out_checks(checks)
    checks.reject! { |check| check.name == workflow_name }
    checks.reject! { |check| check.name != check_name } if !check_name.empty?
    apply_regexp_filter(checks) # if check_regexp is empty, it returns all

    checks
  end

  def all_checks_complete(checks)
    checks.all?(&:completed?)
  end

  def filters_present?
    (!check_name.nil? && !check_name.empty?) || (!check_regexp.nil? && !check_regexp.empty?)
  end

  def fail_if_requested_check_never_run(checks)
    return unless filters_present? && checks&.empty?

    raise StandardError, "The requested check was never run against this ref, exiting..."
  end

  def fail_unless_all_success(checks)
    return if checks.all?(&:success?)

    raise StandardError, "One or more checks were not successful, exiting..."
  end

  def show_checks_conclusion_message(checks)
    puts "Checks completed:"
    puts checks.reduce("") { |message, check|
      "#{message}#{check.conclusion_message}\n"
    }
  end

  def time_is_out?
    consumed_time_seconds % 60 > timeout_minutes
  end

  def exit_with_timeout
    exit 124
  end

  def wait_for_checks
    all_checks = query_check_status

    fail_if_requested_check_never_run(all_checks)

    until all_checks_complete(all_checks) || time_is_out?
      plural_part = all_checks.length > 1 ? "checks aren't" : "check isn't"
      puts "The requested #{plural_part} complete yet, will check back in #{wait} seconds..."
      consumed_time_seconds += wait
      sleep(wait)
      all_checks = query_check_status
    end

    exit_with_timeout if time_is_out?
    show_checks_conclusion_message(all_checks)

    fail_unless_all_success(all_checks)
  end
end
