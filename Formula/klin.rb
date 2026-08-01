# typed: false
# frozen_string_literal: true

# Homebrew formula for the Klin compiler (issue 067).
#
# Install from this repo (clone with access if private):
#   brew tap dart-lang/dart
#   brew install --HEAD --formula Formula/klin.rb
#
# After a public tag vX.Y.Z, uncomment url/sha256 (note/17-homebrew.md)
# and prefer: brew install mrhiden/klin/klin (copy this file into homebrew-klin).
class Klin < Formula
  desc "Systems language that compiles to C"
  homepage "https://github.com/MrHIDEn/klin"
  license "MIT"

  # Stable — enable when the repo/tag is public:
  # url "https://github.com/MrHIDEn/klin/archive/refs/tags/v0.1.0.tar.gz"
  # sha256 "REPLACE_WITH_RELEASE_TARBALL_SHA256"
  # version "0.1.0"

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
