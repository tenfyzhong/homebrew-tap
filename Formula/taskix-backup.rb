# frozen_string_literal: true

class TaskixBackup < Formula
  include Language::Python::Shebang

  desc "Back up and restore Taskix SQLite databases with rclone"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.8.3.tar.gz"
  sha256 "0de9d5eb54a3e6be10e333364c5cca4e2d561339e534f0fe2d3759a22a12f2f3"
  license "MIT"
  head "https://github.com/tenfyzhong/agentix.git", branch: "main"

  bottle do
    root_url "https://github.com/tenfyzhong/agentix/releases/download/0.8.3"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "f05f3c0c96480b35ef9b866407698a12d937d56393ab75e6130f50c2d0f24be0"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "43b2bd8cbd21b6e5b9926dd727515d2206c88562d15dd24b6800685c5ba27ca6"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "ee0c187f626fe0a254f55c43f7d3488b91cc0848e2d8d87c943e415fa6e96c56"
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
