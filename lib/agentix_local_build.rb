# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "rubygems/package"
require "tempfile"
require "uri"

# Native Formula support for installing local precompiled binaries.
module AgentixLocalBuild
  def self.snapshot(name, formula_dir)
    source = ENV.fetch("HOMEBREW_AGENTIX_LOCAL_SOURCE", "")
    return artifact_snapshot(name, source) unless source.empty?

    path = File.expand_path("../share/#{name}/agentix-local.json", formula_dir)
    JSON.parse(File.read(path)) if File.file?(path)
  end

  def self.artifact_snapshot(name, source)
    source = File.realpath(source)
    profile = ENV.fetch("HOMEBREW_AGENTIX_LOCAL_PROFILE", "release")
    raise "Invalid local profile: #{profile}" unless %w[release debug].include?(profile)

    target = ENV.fetch("HOMEBREW_AGENTIX_LOCAL_TARGET_DIR", "")
    target = File.expand_path(target.empty? ? "target" : target, source)
    @snapshots ||= {}
    @snapshots[[name, source, target, profile]] ||= create_snapshot(name, source, target, profile)
  end

  def self.artifact_files(name, source, target, profile)
    binary = File.join(target, profile, name)
    if !File.file?(binary) || !File.executable?(binary)
      command = (profile == "release") ? "make release" : "make"
      raise "Missing executable local binary: #{binary}; run #{command} first"
    end

    files = { "bin/#{name}" => binary }
    ["config/#{name}.example.toml", "completions/#{name}.bash",
     "completions/_#{name}", "completions/#{name}.fish"].each do |path|
      full = File.join(source, path)
      raise "Missing local resource: #{full}" unless File.file?(full)

      files[path] = full
    end
    files
  end

  def self.create_snapshot(name, source, target, profile)
    previous_epoch = ENV.fetch("SOURCE_DATE_EPOCH", nil)
    files = artifact_files(name, source, target, profile)
    cache = defined?(HOMEBREW_CACHE) ? HOMEBREW_CACHE.to_s : ENV.fetch("HOMEBREW_CACHE")
    cache = File.join(cache, "agentix-local-artifacts")
    FileUtils.mkdir_p(cache)
    ENV["SOURCE_DATE_EPOCH"] = "0"
    Tempfile.create(["artifacts-", ".tar.gz"], cache) do |file|
      Tempfile.create(["artifacts-", ".tar"], cache) do |uncompressed|
        Gem::Package::TarWriter.new(uncompressed) do |tar|
          files.sort.each do |path, full|
            tar.add_file_simple(path, File.stat(full).mode, File.size(full)) do |entry|
              File.open(full, "rb") do |input|
                IO.copy_stream(input, entry)
              end
            end
          end
        end
        uncompressed.flush
        # Use the platform gzip to avoid Ruby GzipWriter buffer errors on release binaries.
        unless system("gzip", "-n", "-c", uncompressed.path, out: file)
          raise "Failed to compress local artifact snapshot with gzip"
        end
      end
      file.flush
      digest = Digest::SHA256.file(file.path).hexdigest
      version = "0.0.0-local.#{digest[0, 16]}.#{profile}"
      archive = File.join(cache, "#{version}.tar.gz")
      File.rename(file.path, archive) unless File.file?(archive)
      { "url" => "file://#{URI::DEFAULT_PARSER.escape(archive)}", "version" => version,
        "sha256" => digest, "profile" => profile }
    end
  ensure
    ENV["SOURCE_DATE_EPOCH"] = previous_epoch
  end

  def self.active?(name, formula_dir)
    !snapshot(name, formula_dir).nil?
  end

  def self.configure(formula_class, name, formula_dir)
    data = snapshot(name, formula_dir)
    return unless data

    formula_class.url(data.fetch("url"))
    formula_class.version(data.fetch("version"))
    formula_class.sha256(data.fetch("sha256"))
  end

  def self.install(formula, name, formula_dir)
    library = formula.buildpath/"agentix_local_build.rb"
    FileUtils.cp(__FILE__, library)
    formula.pkgshare.install library
    data = snapshot(name, formula_dir)
    return unless data

    manifest = formula.buildpath/"agentix-local.json"
    File.write(manifest, JSON.generate(data))
    formula.pkgshare.install manifest
  end
end
