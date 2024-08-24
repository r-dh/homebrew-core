class Boolector < Formula
  desc "SMT solver for fixed-size bit-vectors"
  homepage "https://boolector.github.io/"
  url "https://github.com/Boolector/boolector/archive/refs/tags/3.2.4.tar.gz"
  sha256 "249c6dbf4e52ea6e8df1ddf7965d47f5c30f2c14905dce9b8f411756b05878bf"
  license "MIT"

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_sonoma:   "ea5c2d69f9b71ddae1ed7ea577a2db1a9bcb9f8375c1cacafc11375010496580"
    sha256 cellar: :any_skip_relocation, arm64_ventura:  "b9585271d749d85b3dc26971edcd108575b530b8f6c2887909c621be90d25956"
    sha256 cellar: :any_skip_relocation, arm64_monterey: "ddf378009b122b86a5d697a4debe16242dacd72f2af3cf9efeeb7ca886933b09"
    sha256 cellar: :any_skip_relocation, arm64_big_sur:  "a2110fdd745422308573b1159ddf7fcd13137163ba02854ad154b9e73fe54d29"
    sha256 cellar: :any_skip_relocation, sonoma:         "9d44431703ad458ce0eebc51fc4bd7b6965452b25a1127a906984128265a1ba4"
    sha256 cellar: :any_skip_relocation, ventura:        "93d8c0c0c5ea5692791a408565fb90456eb9eadc8f26780d5cab4955d57eef1c"
    sha256 cellar: :any_skip_relocation, monterey:       "a7c5e51ec99b10d52b89e0a84e2f806f2d9ccf81376e6451b62c9e44bf0e0788"
    sha256 cellar: :any_skip_relocation, big_sur:        "df7daa29597266935e0778c69759b9efd8db571dafe06d465022e34959afd3ee"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "f7ae79fa41592f4aad9aa8f227d3ed1105927d8f6f421c6c0fb591438944fa39"
  end

  deprecate! date: "2024-08-24", because: :repo_archived

  depends_on "cmake" => :build

  # Use commit hash from `contrib/setup-lingeling.sh`
  resource "lingeling" do
    url "https://github.com/arminbiere/lingeling/archive/7d5db72420b95ab356c98ca7f7a4681ed2c59c70.tar.gz"
    sha256 "cf04c8f5706c14f00dd66e4db529c48513a450cc0f195242d8d0762b415f4427"
  end

  # Use commit has from `contrib/setup-btor2tools.sh`
  resource "btor2tools" do
    url "https://github.com/boolector/btor2tools/archive/037f1fa88fb439dca6f648ad48a3463256d69d8b.tar.gz"
    sha256 "d6a5836b9e26719c3b7fe1711d93d86ca4720dc9d4bac11d1fc006fa0a140965"
  end

  def install
    deps_dir = buildpath/"deps/install"

    resource("lingeling").stage do
      system "./configure.sh", "-fPIC"
      system "make"
      (deps_dir/"lib").install "liblgl.a"
      (deps_dir/"include").install "lglib.h"
    end

    resource("btor2tools").stage do
      system "./configure.sh", 'CFLAGS="-fPIC"', "--static"
      cd "build" do
        system "cmake", "..", "-DBUILD_SHARED_LIBS=OFF" if OS.mac?
        system "make"
      end
      (deps_dir/"lib").install "build/lib/libbtor2parser.a"
      (deps_dir/"include/btor2parser").install "src/btor2parser/btor2parser.h"
    end

    args = %W[
      -DBtor2Tools_INCLUDE_DIR=#{deps_dir}/include/btor2parser
    ]

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    (testpath/"test.btor").write <<~EOS
      (set-logic BV)
      (declare-fun x () (_ BitVec 4))
      (declare-fun y () (_ BitVec 4))
      (assert (= (bvadd x y) (_ bv6 4)))
      (check-sat)
      (get-value (x y))
    EOS
    assert_match "sat", shell_output("#{bin}/boolector test.btor 2>/dev/null", 1)
  end
end
