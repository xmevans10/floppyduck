#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "time"
require "uri"

API_BASE = "https://api.appstoreconnect.apple.com"
APP_IDENTIFIER = ENV.fetch("APP_IDENTIFIER", "com.xmevans10.FloppyDuck")

def env!(name)
  value = ENV[name].to_s.strip
  abort("Missing #{name}") if value.empty?
  value
end

def asc_private_key
  if ENV["ASC_KEY_FILE"].to_s.strip != ""
    File.read(ENV["ASC_KEY_FILE"])
  else
    env!("ASC_PRIVATE_KEY").gsub("\\n", "\n")
  end
end

def jwt
  require "jwt"
  key_id = env!("ASC_KEY_ID")
  issuer_id = env!("ASC_ISSUER_ID")
  private_key = OpenSSL::PKey::EC.new(asc_private_key)
  now = Time.now.to_i
  payload = { iss: issuer_id, iat: now, exp: now + 20 * 60, aud: "appstoreconnect-v1" }
  JWT.encode(payload, private_key, "ES256", { kid: key_id, typ: "JWT" })
end

def request(method, path, token, body: nil)
  uri = URI("#{API_BASE}#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  klass = Net::HTTP.const_get(method.capitalize)
  req = klass.new(uri)
  req["Authorization"] = "Bearer #{token}"
  req["Content-Type"] = "application/json"
  req.body = JSON.generate(body) if body
  res = http.request(req)
  parsed = res.body.to_s.empty? ? {} : JSON.parse(res.body)
  return parsed if res.is_a?(Net::HTTPSuccess)
  detail = parsed.fetch("errors", []).map { |e| e["detail"] || e["title"] }.join("; ")
  warn("   ⚠️  #{method.upcase} #{path} returned #{res.code}: #{detail}")
  nil
end

PRICES = {
  "com.floppyduck.skin.alien"          => 0.49,
  "com.floppyduck.skin.wizard"         => 0.49,
  "com.floppyduck.skin.devil"          => 0.49,
  "com.floppyduck.theme.space"         => 0.99,
  "com.floppyduck.pipe.neon"           => 0.49,
  "com.floppyduck.pipe.royal"          => 0.49,
  "com.floppyduck.pipe.gold"           => 0.49,
  "com.floppyduck.theme.pixelTokyo"    => 0.99,
  "com.floppyduck.banner.neonTokyo"    => 0.99,
  "com.floppyduck.banner.cosmicRift"   => 0.99,
}.freeze

token = jwt

# Find the app
encoded_bundle = URI.encode_www_form_component(APP_IDENTIFIER)
puts "Finding app..."
apps = request("get", "/v1/apps?filter[bundleId]=#{encoded_bundle}&limit=1", token)
app = apps&.fetch("data")&.first
abort("No app record found for #{APP_IDENTIFIER}") unless app
app_id = app.fetch("id")
puts "   App ID: #{app_id}"

# Fetch all IAPs
puts "Fetching IAPs..."
iaps = request("get", "/v1/apps/#{app_id}/inAppPurchasesV2?limit=200", token)
iap_list = iaps&.fetch("data", []) || []
puts "   Found #{iap_list.length} IAPs\n\n"

# For each IAP, try to create a price schedule with manual prices.
# The price point IDs are the tier-based predefined points.
# For $0.49 and $0.99, we query the price tier relationship.
iap_list.each do |iap|
  product_id = iap.dig("attributes", "productId")
  desired = PRICES[product_id]
  next unless desired

  puts "📦 #{product_id} → $#{'%.2f' % desired}"

  iap_id = iap["id"]

  # Check if price schedule already exists
  existing_schedule = request("get", "/v2/inAppPurchases/#{iap_id}/priceSchedule", token)

  if existing_schedule
    puts "   Already has a price schedule (#{existing_schedule.dig("data", "id")})"
    # Check if it already has manual prices
    prices_check = request("get", "/v1/inAppPurchasePriceSchedules/#{existing_schedule.dig("data", "id")}/manualPrices", token)
    if prices_check && prices_check.fetch("data", []).any?
      puts "   Prices already set — skipping"
      puts ""
      next
    end
  end

  # Fetch available price tiers (not the price point endpoint)
  # The price tier determines the price. We need tier IDs.
  # Tier 1 = $0.99 typically, but we need to query.

  # Alternative: use the v2 IAP price schedule endpoint to create with base territory
  # POST /v2/inAppPurchases/{id}/priceSchedule might accept a simpler payload

  # Actually, let's try the v1 price schedule creation with just the relationships
  begin
    schedule_body = {
      data: {
        type: "inAppPurchasePriceSchedules",
        relationships: {
          inAppPurchase: {
            data: { type: "inAppPurchases", id: iap_id }
          }
        }
      }
    }
    schedule_res = request("post", "/v1/inAppPurchasePriceSchedules", token, body: schedule_body)
    if schedule_res
      schedule_id = schedule_res.dig("data", "id")
      puts "   Price schedule created: #{schedule_id}"

      # Now find price points for the desired amount
      # Query price tiers to find the right tier
      tiers_res = request("get", "/v1/inAppPurchasePriceTiers?limit=200", token)
      if tiers_res
        tiers = tiers_res.fetch("data", [])
        # Map tiers to their price points. We need the price point for the right tier
        tier = tiers.find { |t| t.dig("attributes", "referenceName") == desired.to_s } 

        if tier
          # Get price points for this tier
          points_res = request("get", "/v1/inAppPurchasePriceTiers/#{tier["id"]}/pricePoints", token)
          if points_res
            price_points = points_res.fetch("data", [])
            # Find the USA price point
            usa_point = price_points.find { |p| p.dig("attributes", "territory") == "USA" } || price_points.first

            if usa_point
              price_body = {
                data: {
                  type: "inAppPurchasePrices",
                  relationships: {
                    inAppPurchasePricePoint: {
                      data: { type: "inAppPurchasePricePoints", id: usa_point["id"] }
                    }
                  }
                }
              }
              price_res = request("post", "/v1/inAppPurchasePriceSchedules/#{schedule_id}/manualPrices", token, body: price_body)
              if price_res
                puts "   ✅ Price set to $#{'%.2f' % desired}"
              else
                puts "   ❌ Failed to set manual price"
              end
            else
              puts "   ❌ No price point found for this tier"
            end
          else
            puts "   ❌ Could not fetch price points for tier"
          end
        else
          puts "   ❌ Could not find price tier for $#{'%.2f' % desired}"
        end
      else
        puts "   ❌ Could not fetch price tiers"
      end
    else
      puts "   ❌ Failed to create price schedule"
    end
  rescue => e
    puts "   ❌ Error: #{e.message}"
  end

  puts ""
end

puts "Done! Check https://appstoreconnect.apple.com → In-App Purchases → each IAP's pricing."
