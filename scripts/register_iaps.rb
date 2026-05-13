#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "time"
require "uri"

ROOT = File.expand_path("..", __dir__)
STOREKIT_PATH = File.join(ROOT, "FloppyDuck/Config/FloppyDuckProducts.storekit")
APP_IDENTIFIER = ENV.fetch("APP_IDENTIFIER", "com.xmevans10.FloppyDuck")
API_BASE = "https://api.appstoreconnect.apple.com"
DRY_RUN = ARGV.include?("--dry-run")

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
  payload = {
    iss: issuer_id,
    iat: now,
    exp: now + 20 * 60,
    aud: "appstoreconnect-v1"
  }

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

  detail = parsed.fetch("errors", []).map { |error| error["detail"] || error["title"] }.join("; ")
  abort("#{method.upcase} #{path} failed with #{res.code}: #{detail.empty? ? res.body : detail}")
end

def products
  JSON.parse(File.read(STOREKIT_PATH)).fetch("products").map do |product|
    localization = product.fetch("localizations").find { |entry| entry["locale"] == "en_US" } ||
      product.fetch("localizations").first ||
      {}

    {
      product_id: product.fetch("productID"),
      reference_name: product.fetch("referenceName"),
      display_name: localization["displayName"] || product.fetch("referenceName"),
      description: localization["description"] || product.fetch("referenceName"),
      display_price: product["displayPrice"]
    }
  end
end

if DRY_RUN
  products.each do |product|
    puts "#{product[:product_id]} | #{product[:reference_name]} | #{product[:display_price]} | NON_CONSUMABLE"
  end
  exit 0
end

token = jwt
encoded_bundle_id = URI.encode_www_form_component(APP_IDENTIFIER)
apps = request("get", "/v1/apps?filter[bundleId]=#{encoded_bundle_id}&limit=1", token)
app = apps.fetch("data").first
abort("No App Store Connect app found for #{APP_IDENTIFIER}. Run `bundle exec fastlane ios setup_app` or create the app record first.") unless app

app_id = app.fetch("id")
existing = request("get", "/v1/apps/#{app_id}/inAppPurchasesV2?limit=200", token)
existing_ids = existing.fetch("data", []).map { |iap| iap.dig("attributes", "productId") }.compact

products.each do |product|
  if existing_ids.include?(product[:product_id])
    puts "Exists: #{product[:product_id]}"
    next
  end

  body = {
    data: {
      type: "inAppPurchases",
      attributes: {
        name: product[:reference_name],
        productId: product[:product_id],
        inAppPurchaseType: "NON_CONSUMABLE"
      },
      relationships: {
        app: {
          data: {
            type: "apps",
            id: app_id
          }
        }
      }
    }
  }

  request("post", "/v2/inAppPurchases", token, body: body)
  puts "Created: #{product[:product_id]} (#{product[:display_name]}, #{product[:display_price]})"
end
