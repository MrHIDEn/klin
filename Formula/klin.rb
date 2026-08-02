# typed: false
# frozen_string_literal: true

# Homebrew formula for the Klin compiler (issue 067).
#
# Tap (recommended):
#   brew tap dart-lang/dart
#   brew install mrhiden/klin/klin
#   brew install --HEAD mrhiden/klin/klin
#
# From this clone:
#   brew install --formula Formula/klin.rb
#   brew install --HEAD --formula Formula/klin.rb
# See docs/17-homebrew.md. Keep in sync with MrHIDEn/homebrew-klin.
class Klin < Formula
  desc "Systems language that compiles to C"
  homepage "https://github.com/MrHIDEn/klin"
  license "MIT"
  # Pin the version-bump commit: GitHub may serve a stale
  # refs/tags/v0.1.1.tar.gz after the tag was moved.
  url "https://github.com/MrHIDEn/klin/archive/0ea3216c03ce496aa11a8b5877f907dca99c1424.tar.gz"
  sha256 "dcf378b733e4cb7ba8d6d5fbe92c3f370c354592898a245b1eefb5df31221151"
  version "0.1.1"

  head "https://github.com/MrHIDEn/klin.git", branch: "main"

  depends_on "dart-lang/dart/dart" => :build

  def install
    system "dart", "pub", "get"
    system "dart", "compile", "exe", "bin/klin.dart", "-o", "klin"
    bin.install "klin"
    (pkgshare/"stdlib").install Dir["stdlib/*"]
  end

  def caveats
    <<~EOS
      Klin needs a host C compiler (gcc, clang, or tcc) on PATH for `klin run`.

      Stdlib is installed at:
        #{pkgshare}/stdlib
      (`klin` discovers it next to the binary / under share/klin).
    EOS
  end

  test do
    assert_match(/\d+\.\d+\.\d+/, shell_output("#{bin}/klin --version"))
    (testpath/"hello.kl").write <<~EOS
      fn main() {}
    EOS
    system bin/"klin", "--emit-c", testpath/"hello.kl"
    assert_path_exists testpath/"out/hello.c"
  end
end
