# app.rb
require "sinatra"
require "tmpdir"
require "fileutils"
require "open-uri"

set :server, :puma
set :port, ENV["PORT"] || 3000

# Load install scripts, version files, and other assets at startup
INSTALL_SCRIPT = File.read(File.join(__dir__, "install.sh"))
VERSION = File.read(File.join(__dir__, "VERSION")).strip
ROBOTS = File.read(File.join(__dir__, "robots.txt")).strip
PRO_INSTALL_SCRIPT = begin
  File.read(File.join(__dir__, "pro/install.sh"))
rescue
  ""
end
PRO_VERSION = begin
  File.read(File.join(__dir__, "pro/VERSION")).strip
rescue
  "0.1.0"
end
EXT_HUB_INSTALL_SCRIPT = begin
  File.read(File.join(__dir__, "ext/hub/install.sh"))
rescue
  ""
end
EXT_HUB_VERSION = begin
  File.read(File.join(__dir__, "ext/hub/VERSION")).strip
rescue
  "0.2.0"
end
EXT_VAULT_INSTALL_SCRIPT = begin
  File.read(File.join(__dir__, "ext/vault/install.sh"))
rescue
  ""
end
EXT_VAULT_VERSION = begin
  File.read(File.join(__dir__, "ext/vault/VERSION")).strip
rescue
  "0.1.0"
end

helpers do
  def handle_download(os, name, arch, version = nil)
    arch = arch.gsub(/\.[^\/.]+$/, "").downcase.strip
    version ||= VERSION
    version = version.sub(/^v/, "") if version.start_with?("v")

    binary_name = (os == "windows") ? "#{name}.exe" : name
    repo = "#{name}-#{os}-#{arch}"
    filename = "#{repo}-#{version}.tgz"
    registry_url = "https://registry.npmjs.org/@dotenvx/#{repo}/-/#{filename}"

    Dir.mktmpdir do |tmp_dir|
      tmp_download_path = File.join(tmp_dir, filename)
      tmp_tar_path = File.join(tmp_dir, "output.tgz")

      command = <<~SH
        curl -sS -L #{registry_url} -o #{tmp_download_path} &&
        tar -xzf #{tmp_download_path} -C #{tmp_dir} --strip-components=1 package &&
        chmod 755 #{File.join(tmp_dir, binary_name)} &&
        tar -czf #{tmp_tar_path} -C #{tmp_dir} #{binary_name}
      SH

      system(command)

      if File.exist?(tmp_tar_path)
        send_file tmp_tar_path, filename: filename, type: "application/gzip"
      else
        halt 500, "500 error"
      end
    end
  end

  def format_number(num)
    case num
    when 1_000_000..Float::INFINITY
      "#{(num / 1_000_000.0).round(1)}M"
    when 1_000..999_999
      "#{(num / 1_000.0).round(1)}k"
    else
      num.to_s
    end
  end

  def handle_stats(packages)
    total_downloads = packages.sum do |pkg|
      response = URI.open("https://api.npmjs.org/downloads/point/last-year/#{pkg}")
      data = JSON.parse(response.read)
      data["downloads"]
    rescue
      0
    end

    {
      schemaVersion: 1,
      label: "downloads",
      message: format_number(total_downloads),
      color: "brightgreen"
    }.to_json
  end

  def handle_install(install_script, version = nil, directory = nil)
    result = install_script.dup
    result.gsub!(/VERSION="[^"]*"/, "VERSION=\"#{version}\"") if version
    result.gsub!(/DIRECTORY="[^"]*"/, "DIRECTORY=\"#{directory}\"") if directory
    result
  end
end

get "/" do
  content_type "text/plain"
  handle_install(INSTALL_SCRIPT, params["version"], params["directory"])
end

get "/robots.txt" do
  content_type "text/plain"
  ROBOTS
end

get "/VERSION" do
  content_type "text/plain"
  VERSION
end

get "/install.sh" do
  content_type "text/plain"
  handle_install(INSTALL_SCRIPT, params["version"], params["directory"])
end

# for historical purposes
get "/installer.sh" do
  content_type "text/plain"
  handle_install(INSTALL_SCRIPT, params["version"], params["directory"])
end

# for pro
get "/pro" do
  content_type "text/plain"
  handle_install(PRO_INSTALL_SCRIPT, params["version"], params["directory"])
end

get "/pro/install.sh" do
  content_type "text/plain"
  handle_install(PRO_INSTALL_SCRIPT, params["version"], params["directory"])
end

get "/pro/VERSION" do
  content_type "text/plain"
  PRO_VERSION
end

# for ext/hub
get "/ext/hub" do
  content_type "text/plain"
  handle_install(EXT_HUB_INSTALL_SCRIPT, params["version"], params["directory"])
end

get "/ext/hub/install.sh" do
  content_type "text/plain"
  handle_install(EXT_HUB_INSTALL_SCRIPT, params["version"], params["directory"])
end

get "/ext/hub/VERSION" do
  content_type "text/plain"
  EXT_HUB_VERSION
end

# Ext Vault routes
get "/ext/vault" do
  content_type "text/plain"
  handle_install(EXT_VAULT_INSTALL_SCRIPT, params["version"], params["directory"])
end

get "/ext/vault/install.sh" do
  content_type "text/plain"
  handle_install(EXT_VAULT_INSTALL_SCRIPT, params["version"], params["directory"])
end

get "/ext/vault/VERSION" do
  content_type "text/plain"
  EXT_VAULT_VERSION
end

get "/stats/curl" do
  content_type "application/json"
  handle_stats([
    "@dotenvx/dotenvx-darwin-amd64",
    "@dotenvx/dotenvx-darwin-arm64",
    "@dotenvx/dotenvx-darwin-x86_64",
    "@dotenvx/dotenvx-linux-aarch64",
    "@dotenvx/dotenvx-linux-amd64",
    "@dotenvx/dotenvx-linux-arm64",
    "@dotenvx/dotenvx-linux-x86_64",
    "@dotenvx/dotenvx-windows-amd64",
    "@dotenvx/dotenvx-windows-x86_64"
  ])
end

get "/stats/curl/darwin" do
  content_type "application/json"
  handle_stats([
    "@dotenvx/dotenvx-darwin-amd64",
    "@dotenvx/dotenvx-darwin-arm64",
    "@dotenvx/dotenvx-darwin-x86_64"
  ])
end

get "/stats/curl/linux" do
  content_type "application/json"
  handle_stats([
    "@dotenvx/dotenvx-linux-aarch64",
    "@dotenvx/dotenvx-linux-amd64",
    "@dotenvx/dotenvx-linux-arm64",
    "@dotenvx/dotenvx-linux-x86_64"
  ])
end

get "/stats/curl/windows" do
  content_type "application/json"
  handle_stats([
    "@dotenvx/dotenvx-windows-amd64",
    "@dotenvx/dotenvx-windows-x86_64"
  ])
end

get "/darwin/*" do
  arch = params["splat"].first
  handle_download("darwin", "dotenvx", arch, params["version"])
end

get "/linux/*" do
  arch = params["splat"].first
  handle_download("linux", "dotenvx", arch, params["version"])
end

get "/windows/*" do
  arch = params["splat"].first
  handle_download("windows", "dotenvx", arch, params["version"])
end
