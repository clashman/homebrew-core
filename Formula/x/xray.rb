class Xray < Formula
  desc "Platform for building proxies to bypass network restrictions"
  homepage "https://xtls.github.io/"
  url "https://github.com/XTLS/Xray-core/archive/refs/tags/v1.8.7.tar.gz"
  sha256 "e8f46177d792b89700f164ca28fbf1a3c7d95a3ecf98871cb0dd5e474b46a859"
  license all_of: ["MPL-2.0", "CC-BY-SA-4.0"]
  head "https://github.com/XTLS/Xray-core.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_sonoma:   "067ca1d7c4c56340daedd7cc0a05c266f7ff5c25051327d039d3adf17d3f47b9"
    sha256 cellar: :any_skip_relocation, arm64_ventura:  "a64e8beb3b11d4940e9add0c300808f15724687cb5748d74b5555c4bbcc1ba70"
    sha256 cellar: :any_skip_relocation, arm64_monterey: "12d3b6ee47cdc55d08b4fa9d00f4311242302c360fd81787fc6c53640567df30"
    sha256 cellar: :any_skip_relocation, sonoma:         "1304e8695d57415c3bfedd9c453cc1fb56779eb24957621b5a757fe6227c4b73"
    sha256 cellar: :any_skip_relocation, ventura:        "4997b512ef5cf0c1d8c9ee9097a1bd1e94dfc99e0296b69a41fe943450a1eed9"
    sha256 cellar: :any_skip_relocation, monterey:       "5f48c67aaef77b31792dc66d12c96ab82bb2ac9ca5b84d7e8a2883cccbc94233"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "a57347c5ed836f10707118c0b5ab39f5e54d7e83ad528e5355770791982cab5c"
  end

  depends_on "go" => :build

  resource "geoip" do
    url "https://github.com/v2fly/geoip/releases/download/202401110041/geoip.dat"
    sha256 "37ec29d3aec3d22a575da7d6e858e22a492eafb8abc34a0b288d353acf6ee1a2"
  end

  resource "geosite" do
    url "https://github.com/v2fly/domain-list-community/releases/download/20240105034708/dlc.dat"
    sha256 "9f833c47b103fb475a68d3b0f5db99d7b7c31dd9deab9171781420db10751641"
  end

  resource "example_config" do
    # borrow v2ray example config
    url "https://raw.githubusercontent.com/v2fly/v2ray-core/v5.13.0/release/config/config.json"
    sha256 "1bbadc5e1dfaa49935005e8b478b3ca49c519b66d3a3aee0b099730d05589978"
  end

  def install
    ldflags = "-s -w -buildid="
    execpath = libexec/name
    system "go", "build", *std_go_args(output: execpath, ldflags: ldflags), "./main"
    (bin/"xray").write_env_script execpath,
      XRAY_LOCATION_ASSET: "${XRAY_LOCATION_ASSET:-#{pkgshare}}"

    pkgshare.install resource("geoip")
    resource("geosite").stage do
      pkgshare.install "dlc.dat" => "geosite.dat"
    end
    pkgetc.install resource("example_config")
  end

  def caveats
    <<~EOS
      An example config is installed to #{etc}/xray/config.json
    EOS
  end

  service do
    run [opt_bin/"xray", "run", "--config", "#{etc}/xray/config.json"]
    run_type :immediate
    keep_alive true
  end

  test do
    (testpath/"config.json").write <<~EOS
      {
        "log": {
          "access": "#{testpath}/log"
        },
        "outbounds": [
          {
            "protocol": "freedom",
            "tag": "direct"
          }
        ],
        "routing": {
          "rules": [
            {
              "ip": [
                "geoip:private"
              ],
              "outboundTag": "direct",
              "type": "field"
            },
            {
              "domains": [
                "geosite:private"
              ],
              "outboundTag": "direct",
              "type": "field"
            }
          ]
        }
      }
    EOS
    output = shell_output "#{bin}/xray -c #{testpath}/config.json -test"

    assert_match "Configuration OK", output
    assert_predicate testpath/"log", :exist?
  end
end
