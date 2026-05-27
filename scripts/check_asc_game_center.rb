#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "openssl"
require "time"
require "uri"

ENV_FILE = File.expand_path("../.env", __dir__)
BUNDLE_ID = ENV.fetch("BUNDLE_ID", "com.xmevans10.FloppyDuck")
VERSION = ENV.fetch("MARKETING_VERSION", "1.0")
BUILD_NUMBER = ENV.fetch("BUILD_NUMBER", "10")

def load_dotenv(path)
  return unless File.exist?(path)

  File.readlines(path).each do |raw_line|
    line = raw_line.chomp
    next unless line =~ /\A([A-Za-z_][A-Za-z0-9_]*)=(.*)\z/

    key = Regexp.last_match(1)
    value = Regexp.last_match(2).strip
    value = value[1...-1] if value.start_with?('"') && value.end_with?('"')
    ENV[key] ||= value
  end
end

def base64url(data)
  Base64.urlsafe_encode64(data).delete("=")
end

def jwt_token
  key_id = ENV.fetch("ASC_KEY_ID")
  issuer_id = ENV.fetch("ASC_ISSUER_ID")
  key_file = File.expand_path(ENV.fetch("ASC_KEY_FILE"), File.dirname(ENV_FILE))
  key = OpenSSL::PKey.read(File.read(key_file))
  now = Time.now.to_i
  header = { alg: "ES256", kid: key_id, typ: "JWT" }
  payload = { iss: issuer_id, iat: now, exp: now + 20 * 60, aud: "appstoreconnect-v1" }
  signing_input = "#{base64url(JSON.generate(header))}.#{base64url(JSON.generate(payload))}"
  der = key.dsa_sign_asn1(OpenSSL::Digest::SHA256.digest(signing_input))
  seq = OpenSSL::ASN1.decode(der)
  r, s = seq.value.map { |int| int.value.to_s(2).rjust(32, "\0") }
  "#{signing_input}.#{base64url(r + s)}"
end

def request(path, token)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  req = Net::HTTP::Get.new(uri)
  req["Authorization"] = "Bearer #{token}"
  req["Accept"] = "application/json"
  Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    res = http.request(req)
    body = res.body && !res.body.empty? ? JSON.parse(res.body) : {}
    [res.code.to_i, body]
  end
end

def summarize_response(label, status, body)
  if status >= 400
    errors = Array(body["errors"]).map { |e| "#{e["status"]} #{e["code"]}: #{e["title"]}" }
    puts "#{label}: HTTP #{status} #{errors.join(" | ")}"
  else
    count = body["data"].is_a?(Array) ? body["data"].size : (body["data"] ? 1 : 0)
    puts "#{label}: HTTP #{status} records=#{count}"
  end
end

def attrs(resource)
  resource.fetch("attributes", {})
end

def id_for_first(body)
  data = body["data"]
  data.is_a?(Array) ? data.first&.fetch("id", nil) : data&.fetch("id", nil)
end

load_dotenv(ENV_FILE)
token = jwt_token

status, apps = request("/v1/apps?filter[bundleId]=#{URI.encode_www_form_component(BUNDLE_ID)}&limit=10", token)
summarize_response("apps by bundleId", status, apps)
Array(apps["data"]).each do |app|
  a = attrs(app)
  puts "  app id=#{app["id"]} name=#{a["name"]} bundleId=#{a["bundleId"]} sku=#{a["sku"]}"
end
app_id = id_for_first(apps)

status, bundle_ids = request("/v1/bundleIds?filter[identifier]=#{URI.encode_www_form_component(BUNDLE_ID)}&include=bundleIdCapabilities&limit=10", token)
summarize_response("bundleIds by identifier", status, bundle_ids)
Array(bundle_ids["data"]).each do |bid|
  a = attrs(bid)
  puts "  bundleId id=#{bid["id"]} identifier=#{a["identifier"]} name=#{a["name"]} platform=#{a["platform"]}"
end
Array(bundle_ids["included"]).each do |included|
  next unless included["type"] == "bundleIdCapabilities"

  a = attrs(included)
  puts "  capability #{a["capabilityType"]} setting=#{a["settings"]}"
end
if app_id
  status, game_center_detail_linkage = request("/v1/apps/#{app_id}/relationships/gameCenterDetail", token)
  summarize_response("app gameCenterDetail relationship", status, game_center_detail_linkage)
  game_center_detail_id = id_for_first(game_center_detail_linkage)
  puts "  gameCenterDetail id=#{game_center_detail_id || "nil"}"

  if game_center_detail_id
    status, game_center_detail = request("/v1/gameCenterDetails/#{game_center_detail_id}", token)
    summarize_response("gameCenterDetail", status, game_center_detail)
    if game_center_detail["data"]
      puts "  gameCenterDetail attrs=#{attrs(game_center_detail["data"]).inspect}"
    end

    status, game_center_app_versions = request("/v1/gameCenterDetails/#{game_center_detail_id}/gameCenterAppVersions?include=appStoreVersion&limit=50", token)
    summarize_response("gameCenterAppVersions via detail", status, game_center_app_versions)
    Array(game_center_app_versions["data"]).each do |version|
      a = attrs(version)
      relationship = version.dig("relationships", "appStoreVersion", "data")
      puts "  gameCenterAppVersion id=#{version["id"]} enabled=#{a["enabled"]} appStoreVersion=#{relationship ? relationship["id"] : "nil"}"
    end
    Array(game_center_app_versions["included"]).each do |included|
      next unless included["type"] == "appStoreVersions"

      a = attrs(included)
      puts "  appStoreVersion id=#{included["id"]} version=#{a["versionString"]} state=#{a["appStoreState"]}"
    end
  end

  status, gc_enabled_versions = request("/v1/apps/#{app_id}/gameCenterEnabledVersions?limit=50", token)
  summarize_response("gameCenterEnabledVersions", status, gc_enabled_versions)
  Array(gc_enabled_versions["data"]).each do |version|
    a = attrs(version)
    puts "  gcEnabledVersion id=#{version["id"]} version=#{a["versionString"] || a["version"]} platform=#{a["platform"]}"
  end
end
