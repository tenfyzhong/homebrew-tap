class Modeltap < Formula
  desc "MITM AI traffic monitor with configurable egress proxies"
  homepage "https://github.com/tenfyzhong/modeltap"
  url "https://github.com/tenfyzhong/modeltap/archive/refs/tags/0.1.0.tar.gz"
  sha256 "b572867fbe2501bab6c8c236a949ca62cc1ac3aeaab75134f9ec29f8700501b5"
  license "MIT"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args(path: ".")

    config_dir = etc/"modeltap"
    config_dir.mkpath
    (config_dir/"certs").mkpath
    config_path = config_dir/"config.yaml"
    unless config_path.exist?
      config_path.write <<~YAML
        # Configure sites, TLS MITM, and telemetry before starting the service.
        proxy:
          listen: 127.0.0.1:8080

        logging:
          level: info

        tls:
          ca_cert_file: #{etc}/modeltap/certs/ca-cert.pem
          ca_key_file: #{etc}/modeltap/certs/ca-key.pem

        sites: []

        pricing:
          timezone: UTC
          rules: []
      YAML
    end
  end

  service do
    run [opt_bin/"modeltap", "run", etc/"modeltap/config.yaml"]
    keep_alive true
    log_path var/"log/modeltap.log"
    error_log_path var/"log/modeltap.err.log"
  end

  def caveats
    <<~EOS
      To configure and start ModelTap:
        1. Create CA certificates:
             modeltap ca-init \\
               --cert "$(brew --prefix)/etc/modeltap/certs/ca-cert.pem" \\
               --key "$(brew --prefix)/etc/modeltap/certs/ca-key.pem"
        2. Edit #{etc}/modeltap/config.yaml to configure sites, pricing, TLS, and telemetry.
        3. Start the service:
             brew services start tenfyzhong/tap/modeltap

      Logs are written to:
        #{var}/log/modeltap.log
        #{var}/log/modeltap.err.log
    EOS
  end

  test do
    assert_path_exists etc/"modeltap/config.yaml"
    assert_match "timezone: UTC", (etc/"modeltap/config.yaml").read
    assert_match "ca_cert_file: #{etc}/modeltap/certs/ca-cert.pem", (etc/"modeltap/config.yaml").read
    assert_match "ca_key_file: #{etc}/modeltap/certs/ca-key.pem", (etc/"modeltap/config.yaml").read
    assert_match "modeltap #{version}", shell_output("#{bin}/modeltap --version")
  end
end
