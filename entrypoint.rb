#!/usr/bin/env ruby
require "net/http"
require "uri"
require "json"
require_relative "./models/check"

REPO = ENV["GITHUB_REPOSITORY"]

def query_check_status(ref, token = "")
  uri = URI.parse("https://api.github.com/repos/#{REPO}/commits/#{ref}/check-runs")
  request = Net::HTTP::Get.new(uri)
  request["Accept"] = "application/vnd.github.antiope-preview+json"
  token.empty? || request["Authorization"] = "token #{token}"
  req_options = {
    use_ssl: uri.scheme == "https"
  }
  response = Net::HTTP.start(uri.hostname, uri.port, req_options) { |http|
    http.request(request)
  }

  parse_json_response(response.body)
end

def parse_json_response(json)
  check_runs = JSON.parse(json)["check_runs"]

  check_runs.map do |check|
    Check.new(check['name'], check['status'], check['conclusion'])
  end
end

def apply_regexp_filter(arr, str_regexp)
  arr.select{ |i| i.name[Regexp.new(str_regexp)] }
end

def filter_out_checks(checks, workflow_name, check_name, check_regexp)
  puts "Filtering checks out from: [#{checks.map(&:name).join(', ')}]"
  checks.reject! { |check| check.name == workflow_name }
  puts "Result from filtering out workflow_name (#{workflow_name}): [#{checks.map(&:name).join(', ')}]"
  checks.reject! { |check| !check_name.empty? && check.name == check_name }
  puts "Result from selecting check_name only (#{check_name}): [#{checks.map(&:name).join(', ')}]"
  checks = apply_regexp_filter(checks, check_regexp) # if check_regexp is empty, it returns all
  puts "Result from appling regexp filter (#{check_regexp}): [#{checks.map(&:name).join(', ')}]"
  checks
end

def all_checks_complete(checks)
  checks.all?(&:completed?)
end

def show_checks_statuses(checks)
  puts "Checks #{checks.all?(&:completed?) ? "Completed" : "In Progress"}:"
  puts checks.reduce("") { |message, check|
    "#{message}#{check.conclusion_message}\n"
  }
end
# check_name is the name of the "job" key in a workflow, or the full name if the "name" key
# is provided for job. Probably, the "name" key should be kept empty to keep things short
ref, check_name, check_regexp, token, wait, workflow_name = ARGV
wait = wait.to_i

all_checks = query_check_status(ref, token)
relevant_checks = filter_out_checks(all_checks, check_name, check_regexp, workflow_name)
show_checks_statuses(relevant_checks)

if relevant_checks.empty?
  puts "No checks against this ref to wait, exiting..."
  exit(false)
end

until all_checks_complete(relevant_checks)
  plural_part = relevant_checks.length > 1 ? "checks aren't" : "check isn't"
  puts "The requested #{plural_part} complete yet, will check back in #{wait} seconds..."
  sleep(wait)
  all_checks = query_check_status(ref, token)
  relevant_checks = filter_out_checks(all_checks, check_name, check_regexp, workflow_name)
  show_checks_statuses(relevant_checks)
end

show_checks_statuses(relevant_checks)

# Bail if check is not success
exit(false) unless all_checks.all?(&:success?)
