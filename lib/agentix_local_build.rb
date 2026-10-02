# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "rubygems/package"
require "tempfile"
require "uri"
require "zlib"

# Native Formula support for building the current local source tree.
module AgentixLocalBuild
  def self.snapshot(name, formula_dir)
    source = ENV.fetch("HOMEBREW_AGENTIX_LOCAL_SOURCE", "")
    return source_snapshot(source) unless source.empty?

    path = File.expand_path("../share/#{name}/agentix-local.json", formula_dir)
    JSON.parse(File.read(path)) if File.file?(path)
  end

  def self.source_snapshot(source)
    raise "Invalid local source: Cargo.toml is missing in #{source}" unless File.file?(File.join(source,
                                                                                                 "Cargo.toml"))

    profile = ENV.fetch("HOMEBREW_AGENTIX_LOCAL_PROFILE", "release")
    raise "Invalid local profile: #{profile}" unless %w[release debug].include?(profile)

    source = File.realpath(source)
    @snapshots ||= {}
    @snapshots[[source, profile]] ||= create_snapshot(source, profile)
  end

  def self.source_files(source)
    args = %w[ls-files --cached --others --exclude-standard -z]
    output, status = Open3.capture2("git", "-C", source, *args, err: File::NULL)
    paths = if status.success?
      output.split("\0")
    else
      Dir.glob("**/*", File::FNM_DOTMATCH, base: source)
    end
    paths.uniq.sort.select do |path|
      excluded = path.match?(%r{(?:\A|/)(?:\.git|target|node_modules)(?:/|\z)})
      full = File.join(source, path)
      !excluded && (File.file?(full) || File.symlink?(full))
    end
  end

  def self.create_snapshot(source, profile)
    cache = defined?(HOMEBREW_CACHE) ? HOMEBREW_CACHE.to_s : ENV.fetch("HOMEBREW_CACHE")
    cache = File.join(cache, "agentix-local-source")
    FileUtils.mkdir_p(cache)
    previous_epoch = ENV.fetch("SOURCE_DATE_EPOCH", nil)
    ENV["SOURCE_DATE_EPOCH"] = "0"
    Tempfile.create(["source-", ".tar.gz"], cache) do |file|
      gzip = Zlib::GzipWriter.new(file)
      gzip.mtime = 0
      Gem::Package::TarWriter.new(gzip) do |tar|
        source_files(source).each do |path|
          full = File.join(source, path)
          mode = File.lstat(full).mode
          if File.symlink?(full)
            tar.add_symlink(path, File.readlink(full), mode)
          else
            tar.add_file_simple(path, mode, File.size(full)) do |entry|
              File.open(full, "rb") do |input|
                IO.copy_stream(input, entry)
              end
            end
          end
        end
      end
      gzip.finish
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

  def self.cargo_args(name, formula_dir)
    data = snapshot(name, formula_dir)
    return [] unless data

    (data.fetch("profile") == "debug") ? %w[--all-features --debug] : ["--all-features"]
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
