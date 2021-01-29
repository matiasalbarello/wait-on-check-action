# frozen_string_literal: true
require "active_support/configurable"

require "json"
require "octokit"

class GithubChecksVerifier
  include ActiveSupport::Configurable
  config_accessor :check_name, :workflow_name, :client, :repo, :ref
  config_accessor(:wait) { 30 } # set a default
  config_accessor(:check_regexp) { "" }

  def call
    wait_for_checks
  rescue StandardError => e
    puts e.message
    exit(false)
  end

  def query_check_status(filtering = true)
    checks = client.check_runs_for_ref(repo, ref, { :accept => "application/vnd.github.antiope-preview+json"}).check_runs
    apply_filters(checks) if filtering

    checks
  end

  def apply_filters(checks)
    checks.reject!{ |check| check.name == workflow_name }
    checks.select!{ |check| check.name == check_name } if check_name.present?
    apply_regexp_filter(checks)

    checks
  end

  def apply_regexp_filter(checks)
    checks.select!{ |check| check.name[check_regexp] } if check_regexp.present?
  end

  def all_checks_complete(checks)
    checks.all?{ |check| check.status == "completed" }
  end

  def filters_present?
    check_name.present? || check_regexp.present?
  end

  def get_debug_output
    checks_before_filter = query_check_status(false)
    filters_applied = [
      {name: "workflow_name", value: workflow_name},
      { name: 'check_name', value: check_name },
      { name: 'check_regexp', value: check_regexp }
    ]

    message = "Checks before filter:\n"
    message += checks_status_message(checks_before_filter)
    message += "\nFilters applied: "
    message += filters_applied.map{ |filter| "#{filter[:name]}: #{"<empty_string>" if filter[:value] ==''}#{"<nil>" if filter[:value].nil?}#{"'#{filter[:value]}'" unless filter[:value].nil? || filter[:value]==''}"}.join("\n")
  end

  def fail_if_requested_check_never_run(all_checks, with_debug = true)
    return unless filters_present? && all_checks.blank?

    message = "The requested check was never run against this ref, exiting ...\n"
    message += get_debug_output if with_debug
    raise StandardError, message
  end

  def fail_unless_all_success(checks)
    return if checks.all?{ |check| check.conclusion == "success" }

    raise StandardError, "One or more checks were not successful, exiting..."
  end

  def checks_status_message(checks)
    message = ""
    message += "Checks completed:\n" if all_checks_complete(checks)
    message += checks.reduce("") { |message, check|
      "#{message}#{check.name}: #{check.status} (#{check.conclusion})\n"
    }
  end

  def show_checks_conclusion_message(checks)
    puts checks_status_message(checks)
  end

  def wait_for_checks
    all_checks = query_check_status

    fail_if_requested_check_never_run(all_checks)

    until all_checks_complete(all_checks)
      plural_part = all_checks.length > 1 ? "checks aren't" : "check isn't"
      puts "The requested #{plural_part} complete yet, will check back in #{wait} seconds..."
      sleep(wait)
      all_checks = query_check_status
    end

    show_checks_conclusion_message(all_checks)

    fail_unless_all_success(all_checks)
  end
end
