require 'mkmf'
require 'fileutils'
require 'rbconfig'

LIBDIR      = RbConfig::CONFIG['libdir']
INCLUDEDIR  = RbConfig::CONFIG['includedir']
SITEARCH = RbConfig::CONFIG['sitearch']

OS = case RbConfig::CONFIG['host_os']
     when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
       :windows
     when /darwin|mac os/
       :macosx
     when /linux/
       :linux
     when /solaris|bsd/
       :unix
     else
       fail TypeError, "unknown os: #{host_os.inspect}"
     end

abort "\n\n\n[ERROR]: cmake is required.\n\n\n" unless find_executable('cmake')

if OS == :windows
  abort "\n\n\n[ERROR]: nmake is required.\n\n\n" unless find_executable('nmake')
end

ROOT_TMP = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'tmp'))
CMARK_DIR = File.expand_path(File.join(File.dirname(__FILE__), 'cmark'))
CMARK_BUILD_DIR = File.join(CMARK_DIR, 'build')

# TODO: we need to clear out the build dir that's erroneously getting packaged
# this causes problems, as Linux installation is expecting OS X output
if File.directory?(CMARK_BUILD_DIR) && !File.exist?(ROOT_TMP)
  FileUtils.rm_rf(CMARK_BUILD_DIR)
end
FileUtils.mkdir_p(CMARK_BUILD_DIR)

if OS == :windows
  Dir.chdir(CMARK_BUILD_DIR) do
    system 'cmake  -G "NMake Makefiles"  -D CMAKE_BUILD_TYPE=  -D CMAKE_INSTALL_PREFIX=windows .. && cd ..'
  end
else
  Dir.chdir(CMARK_BUILD_DIR) do
    system 'cmake .. -DCMAKE_C_FLAGS=-fPIC'
    system 'make libcmark_static'
    # rake-compiler seems to complain about this line, not sure why it's messing with it
    FileUtils.rm_rf(File.join(CMARK_BUILD_DIR, 'Testing', 'Temporary'))
  end
end

HEADER_DIRS = [INCLUDEDIR]
LIB_DIRS = [LIBDIR, "#{CMARK_BUILD_DIR}/src"]

dir_config('cmark', HEADER_DIRS, LIB_DIRS)

# don't even bother to do this check if using OS X's messed up system Ruby: http://git.io/vsxkn
if SITEARCH !~ /^universal-darwin/ && OS != :windows
  abort 'libcmark is missing.' unless find_library('cmark', 'cmark_parse_document')
end

$LDFLAGS << " -L#{CMARK_BUILD_DIR}/src -lcmark"
$CFLAGS << " -O2 -I#{CMARK_DIR}/src -I#{CMARK_BUILD_DIR}/src"

create_makefile('commonmarker/commonmarker')
