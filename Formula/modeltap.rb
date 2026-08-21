class Modeltap < Formula
  desc "MITM AI traffic monitor with configurable egress proxies"
  homepage "https://github.com/tenfyzhong/modeltap"
  url "https://github.com/tenfyzhong/modeltap/archive/refs/tags/0.2.5.tar.gz"
  sha256 "2711927e43c3fa49644c1cd3bdd4e4d6eaca48f070e9a5afc17c0145a6f0842f"
  license "MIT"

  bottle do
    root_url "https://github.com/tenfyzhong/modeltap/releases/download/0.2.5"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "4c35b9d19078130ffe1f35288a5a437835a72556ded05e925b10151f04e6027c"
  end

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args(path: ".")

    config_dir = etc/"modeltap"
    config_dir.mkpath
    certs_dir = config_dir/"certs"
    certs_dir.mkpath
    config_path = config_dir/"config.yaml"
    cert_path = certs_dir/"ca-cert.pem"
    key_path = certs_dir/"ca-key.pem"

    unless config_path.exist?
      config = (buildpath/"config.sample.yaml").read
      config.gsub!("./certs/modeltap-ca-cert.pem", cert_path.to_s)
      config.gsub!("./certs/modeltap-ca-key.pem", key_path.to_s)
      config_path.write config
    end

    if !cert_path.exist? && !key_path.exist?
      system bin/"modeltap", "ca-init",
             "--cert", cert_path,
             "--key", key_path
    end

    bash_completion.install "completions/modeltap.bash"
    zsh_completion.install "completions/_modeltap"
    fish_completion.install "completions/modeltap.fish"
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
        1. Trust the CA certificate in Keychain:
             sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain \\
               "$(brew --prefix)/etc/modeltap/certs/ca-cert.pem"
        2. Configure Node.js clients to trust the CA certificate:
             export NODE_EXTRA_CA_CERTS="$(brew --prefix)/etc/modeltap/certs/ca-cert.pem"
        3. Edit #{etc}/modeltap/config.yaml to configure sites, pricing, TLS, and telemetry.
        4. Start the service:
             brew services start tenfyzhong/tap/modeltap

      Logs are written to:
        #{var}/log/modeltap.log
        #{var}/log/modeltap.err.log
    EOS
  end

  test do
    assert_path_exists etc/"modeltap/config.yaml"
    assert_path_exists etc/"modeltap/certs/ca-cert.pem"
    assert_path_exists etc/"modeltap/certs/ca-key.pem"
    assert_path_exists bash_completion/"modeltap.bash"
    assert_path_exists zsh_completion/"_modeltap"
    assert_path_exists fish_completion/"modeltap.fish"
    assert_match "modeltap", shell_output("#{bin}/modeltap --version")
  end
end
