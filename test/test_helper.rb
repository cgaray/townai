# Start SimpleCov for code coverage tracking
require "simplecov"
require "simplecov-cobertura"

SimpleCov.start "rails" do
  # Generate both HTML and Cobertura (XML) formats
  # HTML is for local development, Cobertura is for Codecov
  if ENV["CI"]
    formatter SimpleCov::Formatter::CoberturaFormatter
  else
    multi_formatter = SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::CoberturaFormatter
    ])
    formatter multi_formatter
  end

  # Exclude test files and configuration from coverage
  add_filter "/test/"
  add_filter "/config/"
  add_filter "/vendor/"

  # Set minimum coverage threshold (optional)
  # minimum_coverage 90
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

# Include Devise test helpers for controller tests
class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
