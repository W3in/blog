ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers (Windows has no fork(), so one worker = run in order)
    parallelize(workers: Gem.win_platform? ? 1 : :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  # The header the Nuxt app sends: get "/api/session", headers: auth(users(:alice))
  def auth(user)
    { "Authorization" => "Bearer #{user.auth_token}" }
  end
end
