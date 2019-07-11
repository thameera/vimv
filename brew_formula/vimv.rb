class Vimv < Formula
  desc "vimv is a terminal-based file rename utility that lets you easily mass-rename files using Vim"
  homepage "https://github.com/thameera/vimv"
  url "https://raw.githubusercontent.com/thameera/vimv/master/vimv"
  version "1.0"
  sha256 "b7cd3c652266b53798357b9930645a3415394e9b5da6e6979bb8fa5ac253aa41"
  bottle :unneeded
  def install
     bin.install "vimv"
  end

  test do
  end
end
