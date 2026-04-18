#!/usr/bin/env ruby
# frozen_string_literal: true

# CI/CD Attestation: zip artifacts, SHA-256, Solana memo, optional S3 upload.
# Solana and S3 steps are fault-tolerant: failures are logged, the run
# completes. Standalone (no Rails); see dbb for the Rails-integrated variant.
#
# Environment variables:
#   GITHUB_SHA            commit hash (falls back to git rev-parse HEAD)
#   GITHUB_REPOSITORY     e.g. owner/repo (set by GitHub Actions)
#   ARTIFACT_DIR          directory containing CI artifact files
#                         (default: ".")
#   ARTIFACT_FILES        optional comma-separated manifest of files to
#                         include. Unset -> include all regular files in
#                         ARTIFACT_DIR (flat).
#   EVIDENCE_BUNDLE       optional S3 key prefix root, e.g. "baa-or-not/ci".
#                         Unset -> fall back to "<repo>/ci" derived from
#                         GITHUB_REPOSITORY.
#   SOLANA_KEYPAIR_PATH   path to a 64-byte JSON-array keypair file.
#                         Unset -> skip Solana memo.
#   SOLANA_NETWORK        "devnet" or "mainnet-beta" (default: devnet)
#   S3_COMPLIANCE_BUCKET  S3 bucket. Unset -> skip S3 upload.
#   AWS_REGION            AWS region (default: us-east-1)

require "digest"
require "json"
require "net/http"
require "base64"
require "uri"
require "time"
require "ed25519"

BASE58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

# Memo v2: MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr. Memo v1 no longer
# exists on devnet and will fail with ProgramAccountNotFound.
MEMO_PROGRAM = [
  5, 74, 83, 90, 153, 41, 33, 6,
  77, 36, 232, 113, 96, 218, 56, 124,
  124, 53, 181, 221, 188, 146, 187, 129,
  228, 31, 168, 64, 65, 5, 68, 141
].pack("C*").freeze

ZIP_FILENAME = "ci-artifacts.zip"

def artifact_dir
  ENV.fetch("ARTIFACT_DIR", ".")
end

def commit_sha
  @commit_sha ||= ENV.fetch("GITHUB_SHA") { `git rev-parse HEAD`.strip }
end

def resolve_artifact_files
  manifest = ENV.fetch("ARTIFACT_FILES", "").strip
  if !manifest.empty?
    manifest.split(",").map(&:strip).reject(&:empty?).select do |f|
      File.file?(File.join(artifact_dir, f))
    end
  else
    return [] unless File.directory?(artifact_dir)

    Dir.children(artifact_dir).select { |f| File.file?(File.join(artifact_dir, f)) }
  end
end

def evidence_prefix(short)
  t = Time.now.utc
  explicit = ENV.fetch("EVIDENCE_BUNDLE", "").strip.sub(%r{/+\z}, "")
  repo = (ENV["GITHUB_REPOSITORY"] || "repo").split("/").last
  root = explicit.empty? ? "#{repo}/ci" : explicit
  format(
    "%<root>s/%<y>04d/%<m>02d/%<d>02d/%<hms>s-%<sha>s",
    root: root, y: t.year, m: t.month, d: t.day,
    hms: t.strftime("%H%M%S"), sha: short
  )
end

def base58_to_int(str)
  str.each_char.reduce(0) { |n, c| (n * 58) + BASE58.index(c) }
end

def int_to_bytes(num)
  hex = num.to_s(16)
  hex = "0#{hex}" if hex.length.odd?
  [hex].pack("H*")
end

def base58_decode(str)
  zeros = str.chars.take_while { |c| c == "1" }.length
  (("\x00" * zeros) + int_to_bytes(base58_to_int(str))).b
end

def compact_u16(val)
  out = []
  while val.positive?
    byte = val & 0x7F
    val >>= 7
    byte |= 0x80 if val.positive?
    out << byte
  end
  out.empty? ? "\x00" : out.pack("C*")
end

def zip_artifacts
  present = resolve_artifact_files
  abort "No CI artifact files found in #{artifact_dir}" if present.empty?

  paths = present.map { |f| File.join(artifact_dir, f) }
  system("zip", "-qj", ZIP_FILENAME, *paths) || abort("zip failed")
  present
end

def build_http(uri)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 5
  http.read_timeout = 10
  http
end

def rpc_post(url, method, params = [])
  uri = URI(url)
  body = { jsonrpc: "2.0", id: 1, method: method, params: params }
  req = Net::HTTP::Post.new(uri)
  req["Content-Type"] = "application/json"
  req.body = body.to_json
  JSON.parse(build_http(uri).request(req).body)
end

def load_keypair(path)
  bytes = JSON.parse(File.read(path))
  key = Ed25519::SigningKey.new(bytes[0, 32].pack("C*"))
  [key, key.verify_key]
end

def fetch_blockhash(url)
  resp = rpc_post(url, "getLatestBlockhash")
  bh = resp.dig("result", "value", "blockhash")
  abort "Failed to fetch blockhash" unless bh
  base58_decode(bh)
end

def build_instruction(memo_data)
  [
    [1].pack("C"),
    compact_u16(1),
    [0].pack("C"),
    compact_u16(memo_data.bytesize),
    memo_data,
  ].join
end

def message_header
  [1, 0, 1].pack("CCC")
end

def build_message(pubkey, blockhash, memo)
  [
    message_header,
    compact_u16(2),
    pubkey, MEMO_PROGRAM, blockhash,
    compact_u16(1),
    build_instruction(memo)
  ].join
end

def sign_and_encode(signing_key, message)
  sig = signing_key.sign(message)
  tx = [compact_u16(1), sig, message].join
  Base64.strict_encode64(tx)
end

def solana_url(network)
  return "https://api.mainnet-beta.solana.com" if network == "mainnet-beta"

  "https://api.devnet.solana.com"
end

def build_and_sign(payload, keypair_path, network)
  signing_key, verify_key = load_keypair(keypair_path)
  url = solana_url(network)
  blockhash = fetch_blockhash(url)
  msg = build_message(verify_key.to_bytes, blockhash, payload.to_json)
  [url, sign_and_encode(signing_key, msg)]
end

def submit_memo(payload, keypair_path, network)
  url, encoded = build_and_sign(payload, keypair_path, network)
  result = rpc_post(url, "sendTransaction", [encoded, { encoding: "base64" }])
  raise "Solana RPC error: #{result['error']}" if result["error"]

  result["result"]
end

def s3_upload(bucket, prefix, files)
  region = ENV.fetch("AWS_REGION", "us-east-1")
  files.each do |f|
    next unless File.exist?(f)

    dest = "s3://#{bucket}/#{prefix}/#{File.basename(f)}"
    system("aws", "s3", "cp", f, dest, "--region", region) ||
      warn("Failed to upload #{f}")
  end
end

short = commit_sha[0, 7]
puts "==> Attesting build #{short}..."

included = zip_artifacts
checksum = Digest::SHA256.file(ZIP_FILENAME).hexdigest
puts "SHA-256: #{checksum}"

prefix = evidence_prefix(short)
keypair_path = ENV.fetch("SOLANA_KEYPAIR_PATH", nil)
network = ENV.fetch("SOLANA_NETWORK", "devnet")
signature = nil

if keypair_path && File.exist?(keypair_path)
  memo = {
    s3_key: "#{prefix}/#{ZIP_FILENAME}",
    artifact_checksum: "sha256:#{checksum}",
    commit: commit_sha,
    timestamp: Time.now.utc.iso8601,
  }
  begin
    signature = submit_memo(memo, keypair_path, network)
    puts "Solana memo: #{signature}"
  rescue StandardError => e
    warn "Solana memo failed (non-fatal): #{e.message}"
  end
else
  puts "Skipping Solana memo (no keypair)"
end

bucket = ENV.fetch("S3_COMPLIANCE_BUCKET", nil)
if bucket && !bucket.empty?
  included_paths = included.map { |f| File.join(artifact_dir, f) }
  s3_upload(bucket, prefix, [*included_paths, ZIP_FILENAME])
else
  puts "Skipping S3 upload (no bucket)"
end

puts "==> Attestation complete."

if signature
  cluster = network == "mainnet-beta" ? "" : "?cluster=#{network}"
  puts "Verify: https://explorer.solana.com/tx/#{signature}#{cluster}"
end
