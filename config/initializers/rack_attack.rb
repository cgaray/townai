# frozen_string_literal: true

# Rack::Attack configuration for rate limiting
# Protects against brute force attacks, email bombing, and general abuse

class Rack::Attack
  ### Throttle magic link requests by email ###
  # Prevents email bombing - limit to 5 requests per email per hour
  throttle("magic_link/email", limit: 5, period: 1.hour) do |req|
    if req.path == "/users/sign_in" && req.post?
      # Normalize email to prevent bypass via case differences
      req.params.dig("user", "email")&.to_s&.downcase&.strip
    end
  end

  ### Throttle magic link requests by IP ###
  # Prevents enumeration attacks - limit to 20 requests per IP per hour
  throttle("magic_link/ip", limit: 20, period: 1.hour) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.ip
    end
  end

  ### General request throttle by IP ###
  # Prevents general abuse - 300 requests per 5 minutes per IP
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    # Exclude asset requests from throttling
    req.ip unless req.path.start_with?("/assets")
  end

  ### Custom response for throttled requests ###
  self.throttled_responder = lambda do |req|
    match_data = req.env["rack.attack.match_data"]
    now = match_data[:epoch_time]

    headers = {
      "Content-Type" => "text/html",
      "Retry-After" => (match_data[:period] - (now % match_data[:period])).to_s
    }

    [ 429, headers, [ "Too many requests. Please try again later.\n" ] ]
  end
end

# Enable Rack::Attack
Rails.application.config.middleware.use Rack::Attack
