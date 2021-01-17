#!/usr/bin/env ruby
require_relative "./app/services/github_checks_verifier.rb"

ref, check_name, check_regexp, token, wait, workflow_name = ARGV
GithubChecksVerifier.call(ref, check_name, check_regexp, token, wait, workflow_name)
