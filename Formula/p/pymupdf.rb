class Pymupdf < Formula
  desc "Python bindings for the PDF toolkit and renderer MuPDF"
  homepage "https://pymupdf.readthedocs.io/en/latest/"
  url "https://files.pythonhosted.org/packages/66/52/c87b39831b8989e251464b0db4bbae39a1238829152d863ef224882fdd0e/PyMuPDF-1.24.7.tar.gz"
  sha256 "a34ceae204f215bad51f49dd43987116c6a6269fc03d8770224f7067013b59b8"
  license "AGPL-3.0-only"

  bottle do
    sha256 cellar: :any,                 arm64_sonoma:   "b9893438f9863bb7ca0a59adf1be3ac1043637e4044b0036e6bdd1858e26903c"
    sha256 cellar: :any,                 arm64_ventura:  "aea5f4bf26da29837fc2c7a4c1004d11653d03354ec1dbcd9998390077fbb68d"
    sha256 cellar: :any,                 arm64_monterey: "87c7d76c810c1d13bd9494208ccb6883f5577798b8c5996e2fb1a56a6c0f5593"
    sha256 cellar: :any,                 sonoma:         "626a341728ee34d882a9a4f52196b350452f36ff338229595ad27c3c4b2180cb"
    sha256 cellar: :any,                 ventura:        "17407caced5ad0d9a26ee34eba5bd91beefb1949ab6fddc50e48a631a69d6690"
    sha256 cellar: :any,                 monterey:       "6bd3c2b1fde06502ebc4253ce39daa2b0ea72140f85128076b4444af6b4b1b44"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "ddd09deed9dce85055e4a82f6595cac08b7ccca8475dbc774aa9ede0283370ac"
  end

  depends_on "freetype" => :build
  depends_on "python-setuptools" => :build
  depends_on "swig" => :build
  depends_on "mupdf"
  depends_on "python@3.12"

  def python3
    "python3.12"
  end

  resource "pymupdfb" do
    url "https://files.pythonhosted.org/packages/bc/5d/ca7ef871a342710142805fab3992bb32befce94bed29e7f38d38d0748f25/PyMuPDFb-1.24.6.tar.gz"
    sha256 "f5a40b1732d65a1e519916d698858b9ce7473e23edf9001ddd085c5293d59d30"
  end

  def install
    # Makes setup skip build stage for mupdf
    # https://github.com/pymupdf/PyMuPDF/blob/1.20.0/setup.py#L447
    ENV["PYMUPDF_SETUP_MUPDF_BUILD"] = ""
    # Builds only classic implementation
    # https://github.com/pymupdf/PyMuPDF/issues/2628
    ENV["PYMUPDF_SETUP_IMPLEMENTATIONS"] = "a"
    ENV["PYMUPDF_INCLUDES"] = "#{Formula["mupdf"].opt_include}:#{Formula["freetype"].opt_include}/freetype2"
    ENV["PYMUPDF_MUPDF_LIB"] = Formula["mupdf"].opt_lib.to_s

    system python3, "-m", "pip", "install", *std_pip_args, "."
  end

  test do
    (testpath/"test.py").write <<~EOS
      import sys
      from pathlib import Path

      # per 1.23.9 release, `fitz` module got renamed to `fitz_old`
      import fitz_old as fitz

      in_pdf = sys.argv[1]
      out_png = sys.argv[2]

      # Convert first page to PNG
      pdf_doc = fitz.open(in_pdf)
      pdf_page = pdf_doc.load_page(0)
      png_bytes = pdf_page.get_pixmap().tobytes()

      Path(out_png).write_bytes(png_bytes)
    EOS

    in_pdf = test_fixtures("test.pdf")
    out_png = testpath/"test.png"

    system python3, testpath/"test.py", in_pdf, out_png
    assert_predicate out_png, :exist?
  end
end
