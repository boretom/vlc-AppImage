#!/bin/bash
set -e
set -x

export LANG=C

apt-get update
apt-get --yes install software-properties-common vim

APP="VLC"
LOWERAPP="vlc"
JOBS=4
MULTIARCH=$(dpkg-architecture -qDEB_HOST_MULTIARCH)
export CC=gcc-7
export CXX=g++-7

add-apt-repository ppa:ubuntu-toolchain-r/test --yes
apt-get update
sudo apt-get -y install --no-install-recommends \
 autoconf \
 automake \
 bison \
 build-essential \
 cmake \
 fuse \
 gcc-7 \
 g++-7 \
 gettext \
 git \
 librsvg2-bin \
 liba52-0.7.4-dev \
 libasound2-dev \
 libass-dev \
 libcddb2-dev \
 libchromaprint-dev \
 libdbus-1-dev \
 libfontconfig1-dev \
 libfreetype6-dev \
 libgcrypt11-dev \
 libgl1-mesa-dev \
 libgnutls28-dev \
 libgtk2.0-dev \
 libidn11-dev \
 libjpeg-dev \
 liblua5.2-dev \
 libmad0-dev \
 libmatroska-dev \
 libnotify-dev \
 libogg-dev \
 libpng-dev \
 libpulse-dev \
 librsvg2-dev \
 libtag1-dev \
 libtar-dev \
 libtool \
 libudev-dev \
 libva-dev \
 libvorbis-dev \
 libx11-dev \
 libxcb1-dev \
 libxcb-composite0-dev \
 libxcb-keysyms1-dev \
 libxcb-randr0-dev \
 libxcb-shm0-dev \
 libxcb-xv0-dev \
 libxext-dev \
 libxft-dev \
 libxinerama-dev \
 libxml2-dev \
 libxpm-dev \
 lua5.2 \
 mercurial \
 patch \
 pkg-config \
 protobuf-compiler \
 qtbase5-private-dev \
 libqt5svg5-dev \
 wget \
 zlib1g-dev

VERSION=$(wget -q "https://www.videolan.org/vlc/#download" -O - | grep -o -E '"Linux","latestVersion":"([^"#]+)"' | cut -d'"' -f6)
TOP="$PWD"

mkdir -p vlc-build
cd vlc-build

# download
test -d ffmpeg || git clone --depth 1 -b release/4.2 "https://github.com/FFmpeg/FFmpeg.git" ffmpeg
test -d libdvdcss || git clone --depth 1 "http://code.videolan.org/videolan/libdvdcss.git"
test -d libdvdread || git clone --depth 1 "http://code.videolan.org/videolan/libdvdread.git"
test -d libdvdnav || git clone --depth 1 "http://code.videolan.org/videolan/libdvdnav.git"
test -d libbluray || git clone --depth 1 "http://code.videolan.org/videolan/libbluray.git"
test -d x264 || git clone --depth 1 "http://code.videolan.org/videolan/x264.git"
#test -d x265 || hg clone "https://bitbucket.org/multicoreware/x265"
test -d x265 || git clone "https://github.com/videolan/x265"
test -d patchelf || git clone "https://github.com/NixOS/patchelf.git"
wget -c "http://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz"
wget -c "http://www.nasm.us/pub/nasm/releasebuilds/2.13.01/nasm-2.13.01.tar.xz"
wget -c "http://download.videolan.org/pub/videolan/vlc/$VERSION/vlc-$VERSION.tar.xz"

# sources
cat <<EOF> SOURCES
vlc:         http://download.videolan.org/pub/videolan/vlc/$VERSION/vlc-$VERSION.tar.xz
ffmpeg:      https://github.com/FFmpeg/FFmpeg.git               $(git -C ffmpeg log -1 | head -n1) branch release/4.2
libdvdcss:   http://code.videolan.org/videolan/libdvdcss.git    $(git -C libdvdcss log -1 | head -n1)
libdvdread:  http://code.videolan.org/videolan/libdvdread.git   $(git -C libdvdread log -1 | head -n1)
libdvdnav:   http://code.videolan.org/videolan/libdvdnav.git    $(git -C libdvdnav log -1 | head -n1)
libbluray:   http://git.videolan.org/git/libbluray.git          $(git -C libbluray log -1 | head -n1)
x264:        http://git.videolan.org/git/x264.git               $(git -C x264 log -1 | head -n1)
x265:        https://github.com/videolan/x265.git               $(git -C x265 log -1 | head -n1)
dialog:      https://github.com/darealshinji/AppImageKit-dialog
patchelf     https://github.com/NixOS/patchelf.git

Build system:
$(lsb_release -irc)
$(uname -mo)

Package repositories:
$(cat /etc/apt/sources.list /etc/apt/sources.list.d/* | grep '^deb ')
EOF

BUILD_ROOT="$PWD"
export PREFIX="$BUILD_ROOT/usr"
export PATH="$PREFIX/bin:$PATH"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
export CFLAGS="-O3 -fstack-protector -I$PREFIX/include"
export CXXFLAGS="$CFLAGS"
export CPPFLAGS="-I$PREFIX/include -D_FORTIFY_SOURCE=2"
export LDFLAGS="-Wl,-z,relro -Wl,--as-needed -L$PREFIX/lib"

# nasm
if [ ! -e ./usr/bin/nasm ]; then
  rm -rf nasm-2.13.01
  tar xf nasm-2.13.01.tar.xz
  cd nasm-2.13.01
  ./configure --prefix="$PREFIX"
  make -j$JOBS V=0
  make install
  cd -
fi

# yasm
if [ ! -e ./usr/bin/yasm ]; then
  rm -rf yasm-1.3.0
  tar xf yasm-1.3.0.tar.gz
  cd yasm-1.3.0
  ./configure --prefix="$PREFIX"
  make -j$JOBS V=0
  make install-strip
  cd -
fi

# x264
if [ ! -e ./usr/lib/libx264.so ]; then
  cd x264
  ./configure --prefix="$PREFIX" --enable-shared --disable-cli --enable-strip
  make clean
  make -j$JOBS V=0
  make install
  cd -
fi

# x265
if [ ! -e ./usr/lib/libx265.so ]; then
  rm -rf x265/source/build
  mkdir -p x265/source/build
  cd x265/source/build
  cmake .. -DCMAKE_CXX_FLAGS="$CXXFLAGS" -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS -s" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DENABLE_CLI="OFF" -DENABLE_LIBNUMA="OFF"
  make -j$JOBS
  make install
  cd -
fi

# patchelf
if [ ! -e /usr/bin/patchelf ]; then
  cd patchelf
  ./bootstrap.sh
  ./configure
  make -j$JOBS
  make install
  cd -
fi

# dvdcss
if [ ! -e ./usr/lib/libdvdcss.so ]; then
  cd libdvdcss
  autoreconf -if
  ./configure --prefix="$PREFIX" --enable-shared --disable-static
  make clean
  make -j$JOBS V=0
  make install-strip
  cd -
fi

# dvdread
if [ ! -e ./usr/lib/libdvdread.so ]; then
  cd libdvdread
  autoreconf -if
  ./configure --prefix="$PREFIX" --enable-shared --disable-static --with-libdvdcss
  make clean
  make -j$JOBS V=0
  make install-strip
  cd -
fi

# dvdnav
if [ ! -e ./usr/lib/libdvdnav.so ]; then
  cd libdvdnav
  autoreconf -if
  ./configure --prefix="$PREFIX" --enable-shared --disable-static
  make clean
  make -j$JOBS V=0
  make install-strip
  cd -
fi

# bluray
if [ ! -e ./usr/lib/libbluray.so ]; then
  cd libbluray
  git submodule init
  git submodule update
  autoreconf -if
  ./configure --prefix="$PREFIX" --enable-shared --disable-static --disable-bdjava-jar --disable-doxygen-doc
  make clean
  make -j$JOBS V=0
  make install-strip
  cd -
fi

# ffmpeg
if [ ! -e ./usr/lib/libavcodec.so ]; then
  cd ffmpeg
  ./configure --prefix="$PREFIX" --enable-shared --disable-static --disable-debug --disable-programs --disable-doc
  make clean
  make -j$JOBS
  make install
  cd -
fi

# vlc
rm -rf vlc-$VERSION
tar xf vlc-$VERSION.tar.xz
cd vlc-$VERSION
#./configure --prefix=/usr --disable-rpath --enable-skins2 --disable-ncurses
./configure --prefix=/usr --disable-rpath --disable-ncurses
sed -i '/# pragma STDC/d' config.h  # -Wunknown-pragmas
#patch -p1 < "$TOP/x264_bit_depth.patch"
make clean
make -j$JOBS
make install-strip DESTDIR="$BUILD_ROOT"
cd -

# refresh cache
cd "$PREFIX/lib/vlc"
rm plugins/*.dat
LD_LIBRARY_PATH="$PREFIX/lib" ./vlc-cache-gen plugins
cd -

# move to AppDir
rm -rf $APP.AppDir
mkdir $APP.AppDir
cd $APP.AppDir

# copy files
cp -r ../usr .
cp -r /usr/lib/$MULTIARCH/qt5/plugins/ ./usr/lib/
cp ../SOURCES .
cp "$TOP/x264_bit_depth.patch" .

# qt.conf
cat <<EOF> ./usr/bin/qt.conf
[Paths]
Plugins = ../lib/plugins
lib = ../lib
EOF

# delete unwanted files
cd usr
rm -vf bin/bd* bin/*asm lib/*.so
rm -vf $(find lib -name '*.la') $(find lib -name '*.a')
rm -rf include lib/pkgconfig share/doc share/man
cd -

# appdata file
mkdir -p usr/share/appdata
cp "$TOP/vlc.appdata.xml" usr/share/appdata/  # from http://tinyurl.com/y7tq3u4s
ln -s appdata usr/share/metainfo

# bundle AppImage
unset LD_LIBRARY_PATH
wget -c -q https://github.com/AppImage/AppImages/raw/master/functions.sh -O ../functions.sh
. ../functions.sh
copy_deps
move_lib
delete_blacklisted
rm -rvf usr/lib/$MULTIARCH/pulseaudio/ usr/lib/$MULTIARCH/libpulse.so.0  # pulseaudio issues
rm -rf $(echo "$PWD" | cut -d '/' -f2)  # removes i.e. "home" from AppDir
cp "$TOP/vlc.desktop" .
get_icon
patch_usr
get_apprun

# desktop integration
wget -c https://github.com/darealshinji/AppImageKit-dialog/releases/download/continuous/dialog-x86_64 -O dialog
cp "$TOP/dialog-desktopintegration.sh" usr/bin/${LOWERAPP}.wrapper
chmod a+x dialog usr/bin/${LOWERAPP}.wrapper

GLIBC_NEEDED=$(glibc_needed)

cd ..
generate_type2_appimage

