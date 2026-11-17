# frozen_string_literal: true

class TaskixBackup < Formula
  include Language::Python::Shebang

  desc "Back up and restore Taskix SQLite databases with rclone"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.8.1.tar.gz"
  sha256 "0dcc9ceccb6bfb3d05ab1274ceef207c80ca2567ef42760276db299fec53f53f"
  license "MIT"
  head "https://github.com/tenfyzhong/agentix.git", branch: "main"

  bottle do
    root_url "https://github.com/tenfyzhong/agentix/releases/download/0.8.1"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "fa97d176c6a74aa79db6d6e09a9243f4206bf847c8c7b52a625c34f307ae4f44"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "841e3a63dc24d9cc9db7841605f76ee707be379cf5067e9292f9837cbf7bb600"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "ba95d66eec6f819ff789a33f3ff56ee6557a5551cb36bf5ca0d9f824894d0015"
  end

  depends_on "python@3.14"
  depends_on "rclone"

  def install
    rewrite_shebang detected_python_shebang, "scripts/taskix-backup.py"
    bin.install "scripts/taskix-backup.py" => "taskix-backup"
  end

  def caveats
    <<~EOS
      Run taskix-backup --help to see backup and restore options.
      Backups use your existing Taskix configuration and a named rclone remote.
      Configure the remote with rclone config before your first backup.
      Schedule backups separately; installing this formula does not start them.
    EOS
  end

  test do
    assert_match "--restore", shell_output("#{bin}/taskix-backup --help")
    python = formula_opt_bin("python@3.14")/"python3.14"
    system python, "-c", <<~PYTHON
      import sqlite3
      with sqlite3.connect("tasks.sqlite3") as database:
          database.execute("CREATE TABLE evidence (value TEXT)")
          database.execute("INSERT INTO evidence VALUES ('preserved')")
    PYTHON
    (testpath/"taskix.toml").write <<~TOML
      schema_version = 1
      [storage]
      path = "#{testpath}/tasks.sqlite3"
    TOML
    (testpath/"rclone.conf").write <<~INI
      [backup-test]
      type = local
    INI
    ENV["TASKIX_MEMORY_ENABLED"] = "false"
    system bin/"taskix-backup", "--config", testpath/"taskix.toml",
           "--output-dir", testpath/"backups", "--remote", "backup-test:#{testpath}/remote",
           "--rclone", formula_opt_bin("rclone")/"rclone", "--rclone-config", testpath/"rclone.conf"
    archives = (testpath/"backups").glob("*.tar.gz")
    assert_equal 1, archives.length
    assert_equal archives.first.binread, (testpath/"remote"/archives.first.basename).binread
    system bin/"taskix-backup", "--restore", archives.first, "--restore-dir", testpath/"restored"
    output = shell_output("#{python} -c 'import sqlite3; print(sqlite3.connect(\"restored/tasks.sqlite3\")" \
                          ".execute(\"SELECT value FROM evidence\").fetchone()[0])'")
    assert_equal "preserved", output.strip
  end
end
