# frozen_string_literal: true

class TaskixBackup < Formula
  include Language::Python::Shebang

  desc "Back up and restore Taskix SQLite databases with rclone"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.8.4.tar.gz"
  sha256 "48839d75bb385ff618e463f1165834e0b9a0d5ee853822764bf9d2a37655d509"
  license "MIT"
  head "https://github.com/tenfyzhong/agentix.git", branch: "main"

  bottle do
    root_url "https://github.com/tenfyzhong/agentix/releases/download/0.8.4"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "754c049eef1a8050c35d5c857a3b913325acf4bc98bc8119dc5edc52a981b8bc"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "7df7680d96b9137abee32c9970562e1f3cdaa18a5b9669c1711485bb06f18fdc"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "e503413c02b39a57a26080e75a03d91493bee6ed0de9d1dbff5657a9857418da"
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
