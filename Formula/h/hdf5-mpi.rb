class Hdf5Mpi < Formula
  desc "File format designed to store large amounts of data"
  homepage "https://www.hdfgroup.org/solutions/hdf5/"
  url "https://github.com/HDFGroup/hdf5/releases/download/hdf5_1.14.5/hdf5-1.14.5.tar.gz"
  sha256 "ec2e13c52e60f9a01491bb3158cb3778c985697131fc6a342262d32a26e58e44"
  license "BSD-3-Clause"
  version_scheme 1

  livecheck do
    formula "hdf5"
  end

  bottle do
    sha256 cellar: :any,                 arm64_sequoia: "eec09d2c2f23cf130b786e851f66bc32610df1724ccbb490b0d35bc161361e75"
    sha256 cellar: :any,                 arm64_sonoma:  "1e8e5ff1d27f4f34fe77bf58abdcb109b6b74d2df9cba39498ebc0c55e3beb74"
    sha256 cellar: :any,                 arm64_ventura: "e4251e0539e17df918c6494f3b3bf9eceef56afe8f3a059a18f946170e93d22f"
    sha256 cellar: :any,                 sonoma:        "7a25eb0cf131fe6102c0da260487f7efc5a82b5a123c904d969ac7c17254bdbd"
    sha256 cellar: :any,                 ventura:       "bac8acfd061c9ea17d89ffb3304388b88e05c298c033893e710cdf2a30a6d2ff"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "b93050e18e61f3669266c6370f9ca19cbcec58c20941de8e0f674429f28de969"
  end

  depends_on "cmake" => :build
  depends_on "gcc" # for gfortran
  depends_on "libaec"
  depends_on "open-mpi"
  depends_on "pkg-config"

  uses_from_macos "zlib"

  conflicts_with "hdf5", because: "hdf5-mpi is a variant of hdf5, one can only use one or the other"

  # Workaround for upstream breakage to `libaec` detection and pkg-config flags
  # Issue ref: https://github.com/HDFGroup/hdf5/issues/4949
  patch :DATA

  def install
    ENV["libaec_DIR"] = Formula["libaec"].opt_prefix.to_s
    args = %w[
      -DHDF5_USE_GNU_DIRS:BOOL=ON
      -DHDF5_INSTALL_CMAKE_DIR=lib/cmake/hdf5
      -DHDF5_ENABLE_PARALLEL:BOOL=ON
      -DALLOW_UNSUPPORTED:BOOL=ON
      -DHDF5_BUILD_FORTRAN:BOOL=ON
      -DHDF5_BUILD_CPP_LIB:BOOL=ON
      -DHDF5_ENABLE_SZIP_SUPPORT:BOOL=ON
    ]

    # https://github.com/HDFGroup/hdf5/issues/4310
    args << "-DHDF5_ENABLE_NONSTANDARD_FEATURE_FLOAT16:BOOL=OFF"

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args

    # Avoid c shims in settings files
    inreplace_c_files = %w[
      build/src/H5build_settings.c
      build/src/libhdf5.settings
    ]
    inreplace inreplace_c_files, Superenv.shims_path/ENV.cc, ENV.cc

    # Avoid cpp shims in settings files
    inreplace_cxx_files = %w[
      build/CMakeFiles/h5c++
      build/CMakeFiles/h5hlc++
    ]
    inreplace_cxx_files << "build/src/libhdf5.settings" if OS.linux?
    inreplace inreplace_cxx_files, Superenv.shims_path/ENV.cxx, ENV.cxx

    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <stdio.h>
      #include "hdf5.h"
      int main()
      {
        printf("%d.%d.%d\\n", H5_VERS_MAJOR, H5_VERS_MINOR, H5_VERS_RELEASE);
        return 0;
      }
    EOS
    system bin/"h5pcc", "test.c"
    assert_equal version.major_minor_patch.to_s, shell_output("./a.out").chomp

    (testpath/"test.f90").write <<~EOS
      use hdf5
      integer(hid_t) :: f, dspace, dset
      integer(hsize_t), dimension(2) :: dims = [2, 2]
      integer :: error = 0, major, minor, rel

      call h5open_f (error)
      if (error /= 0) call abort
      call h5fcreate_f ("test.h5", H5F_ACC_TRUNC_F, f, error)
      if (error /= 0) call abort
      call h5screate_simple_f (2, dims, dspace, error)
      if (error /= 0) call abort
      call h5dcreate_f (f, "data", H5T_NATIVE_INTEGER, dspace, dset, error)
      if (error /= 0) call abort
      call h5dclose_f (dset, error)
      if (error /= 0) call abort
      call h5sclose_f (dspace, error)
      if (error /= 0) call abort
      call h5fclose_f (f, error)
      if (error /= 0) call abort
      call h5close_f (error)
      if (error /= 0) call abort
      CALL h5get_libversion_f (major, minor, rel, error)
      if (error /= 0) call abort
      write (*,"(I0,'.',I0,'.',I0)") major, minor, rel
      end
    EOS
    system bin/"h5pfc", "test.f90"
    assert_equal version.major_minor_patch.to_s, shell_output("./a.out").chomp

    # Make sure that it was built with SZIP/libaec
    config = shell_output("#{bin}/h5cc -showconfig")
    assert_match %r{I/O filters.*DECODE}, config
  end
end

__END__
diff --git a/CMakeFilters.cmake b/CMakeFilters.cmake
index 52d65e5..b43aa3b 100644
--- a/CMakeFilters.cmake
+++ b/CMakeFilters.cmake
@@ -108,7 +108,7 @@ if (HDF5_ENABLE_Z_LIB_SUPPORT)
         # on the target. The target returned is: ZLIB::ZLIB
         get_filename_component (libname ${ZLIB_LIBRARIES} NAME_WLE)
         string (REGEX REPLACE "^lib" "" libname ${libname})
-        set_target_properties (ZLIB::ZLIB PROPERTIES OUTPUT_NAME zlib-static)
+        set_target_properties (ZLIB::ZLIB PROPERTIES OUTPUT_NAME z)
         set (LINK_COMP_LIBS ${LINK_COMP_LIBS} ZLIB::ZLIB)
       endif ()
     else ()
@@ -152,7 +152,7 @@ if (HDF5_ENABLE_SZIP_SUPPORT)
     endif ()
     set(libaec_USE_STATIC_LIBS ${HDF5_USE_LIBAEC_STATIC})
     set(SZIP_FOUND FALSE)
-    find_package (SZIP NAMES ${LIBAEC_PACKAGE_NAME}${HDF_PACKAGE_EXT} COMPONENTS ${LIBAEC_SEACH_TYPE})
+    find_package (libaec REQUIRED CONFIG)
     if (NOT SZIP_FOUND)
       find_package (SZIP) # Legacy find
     endif ()
@@ -160,7 +160,8 @@ if (HDF5_ENABLE_SZIP_SUPPORT)
     if (H5_SZIP_FOUND)
       set (H5_SZIP_INCLUDE_DIR_GEN ${SZIP_INCLUDE_DIR})
       set (H5_SZIP_INCLUDE_DIRS ${H5_SZIP_INCLUDE_DIRS} ${SZIP_INCLUDE_DIR})
-      set (LINK_COMP_LIBS ${LINK_COMP_LIBS} ${SZIP_LIBRARIES})
+      set (LINK_COMP_LIBS ${LINK_COMP_LIBS} libaec::sz)
+      set_target_properties (libaec::sz PROPERTIES OUTPUT_NAME sz)
     endif ()
   else ()
     if (HDF5_ALLOW_EXTERNAL_SUPPORT MATCHES "GIT" OR HDF5_ALLOW_EXTERNAL_SUPPORT MATCHES "TGZ")
