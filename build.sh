#!/bin/bash
set -e
set -x

export LANG=C

APP="VLC"
LOWERAPP="vlc"
JOBS=4
MULTIARCH=$(dpkg-architecture -qDEB_HOST_MULTIARCH)

sudo apt-get -y update
sudo apt-get -y --allow-unauthenticated upgrade  # google chrome issues on Travis
sudo apt-get -y install --no-install-recommends \
 autoconf \
 automake \
 build-essential \
 fuse \
 gettext \
 git \
 liba52-0.7.4-dev \
 libasound2-dev \
 libass-dev \
 libcddb2-dev \
 libdbus-1-dev \
 libfreetype6-dev \
 libgcrypt11-dev \
 libgl1-mesa-dev \
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
 libqt4-dev \
 libqt4-dev-bin \
 libqt4-opengl-dev \
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
 libxinerama-dev \
 libxml2-dev \
 libxpm-dev \
 lua5.2 \
 pkg-config \
 wget \
 zlib1g-dev

VERSION=$(wget -q "https://www.videolan.org/vlc/#download" -O - | grep -o -E '"Linux","latestVersion":"([^"#]+)"' | cut -d'"' -f6)

mkdir -p vlc-build
cd vlc-build

# download
test -d ffmpeg || git clone --depth 1 -b release/2.8 "https://github.com/FFmpeg/FFmpeg.git" ffmpeg
test -d libdvdcss || git clone --depth 1 "http://code.videolan.org/videolan/libdvdcss.git"
test -d libdvdread || git clone --depth 1 "http://code.videolan.org/videolan/libdvdread.git"
test -d libdvdnav || git clone --depth 1 "http://code.videolan.org/videolan/libdvdnav.git"
test -d libbluray || git clone --depth 1 "http://git.videolan.org/git/libbluray.git"
wget -c "http://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz"
wget -c "http://download.videolan.org/pub/videolan/vlc/$VERSION/vlc-$VERSION.tar.xz"

# sources
cat <<EOF> SOURCES
vlc:         http://download.videolan.org/pub/videolan/vlc/$VERSION/vlc-$VERSION.tar.xz
ffmpeg:      https://github.com/FFmpeg/FFmpeg.git              $(git -C ffmpeg log -1 | head -n1) branch release/2.8
libdvdcss:   http://code.videolan.org/videolan/libdvdcss.git   $(git -C libdvdcss log -1 | head -n1)
libdvdread:  http://code.videolan.org/videolan/libdvdread.git  $(git -C libdvdread log -1 | head -n1)
libdvdnav:   http://code.videolan.org/videolan/libdvdnav.git   $(git -C libdvdnav log -1 | head -n1)
libbluray:   http://git.videolan.org/git/libbluray.git         $(git -C libdbluray log -1 | head -n1)

Build system:
$(lsb_release -irc)
$(uname -mo)
EOF

BUILD_ROOT="$PWD"
export PREFIX="$BUILD_ROOT/usr"
export PATH="$PREFIX/bin:$PATH"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
export CFLAGS="-O3 -fstack-protector -I$PREFIX/include"
export CXXFLAGS="$CFLAGS"
export CPPFLAGS="-I$PREFIX/include -D_FORTIFY_SOURCE=2"
export LDFLAGS="-Wl,-z,relro -Wl,--as-needed -L$PREFIX/lib"

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
./configure --prefix=/usr --disable-rpath --enable-skins2 --disable-ncurses
sed -i '/# pragma STDC/d' config.h  # -Wunknown-pragmas
make -j$JOBS
make install-strip DESTDIR="$BUILD_ROOT"
cd -

# refresh cache
cd "$PREFIX/lib/vlc"
LD_LIBRARY_PATH="$PREFIX/lib" ./vlc-cache-gen -f plugins
cd -

# move to AppDir
rm -rf $APP.AppDir
mkdir $APP.AppDir
cd $APP.AppDir

# copy files
cp -r ../usr .
cp -r /usr/lib/$MULTIARCH/qt4/plugins/ ./usr/lib/
cp ../SOURCES .

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
# pulseaudio issues
rm -rvf lib/$MULTIARCH/pulseaudio/
rm -vf lib/$MULTIARCH/libpulse.so.0
cd -

# appdata file
mkdir -p ./usr/share/appdata
cat <<EOF> ./usr/share/appdata/${LOWERAPP}.appdata.xml  # from http://tinyurl.com/y7tq3u4s
<?xml version="1.0" encoding="UTF-8"?>
<!-- Copyright 2016 Jean-Baptiste Kempf -->

<component type="desktop">
    <id>${LOWERAPP}.desktop</id>
    <metadata_license>CC0-1.0</metadata_license>
    <name>VLC</name>
    <summary>VLC media player, the open-source multimedia player</summary>
    <description>
        <p>
            VLC is a free and open source cross-platform multimedia player and
            framework that plays most multimedia files as well as DVDs, Audio CDs,
            VCDs, and various streaming protocols.
        </p>
    </description>
    <url type="homepage">https://www.videolan.org/vlc/</url>
    <url type="bugtracker">https://trac.videolan.org/vlc/</url>
    <url type="donation">https://www.videolan.org/contribute.html</url>
    <releases>
        <release version="$VERSION" />
    </releases>
    <project_group>VideoLAN</project_group>
    <project_license>GPL-2.0+</project_license>
    <developer_name>VideoLAN et al.</developer_name>
    <update_contact>vlc-devel -- videolan.org</update_contact>
    <screenshots>
        <screenshot type="default">http://images.videolan.org/vlc/screenshots/2.0.0/vlc-2.0-poney.jpg</screenshot>
        <screenshot type="default">http://images.videolan.org/vlc/screenshots/2.0.0/vlc-2.0-gnome3-open.jpg</screenshot>
        <screenshot type="default">http://images.videolan.org/vlc/screenshots/2.0.0/vlc-2.0-gnome3-debian.jpg</screenshot>
    </screenshots>
</component>
EOF

# bundle AppImage
unset LD_LIBRARY_PATH
wget -c -q https://github.com/AppImage/AppImages/raw/master/functions.sh -O ../functions.sh
. ../functions.sh
copy_deps
move_lib
delete_blacklisted
rm -rf $(echo "$PWD" | cut -d '/' -f2)  # removes i.e. "home" from AppDir
get_desktop
fix_desktop ${LOWERAPP}.desktop
sed -i 's|/usr/bin/||g' ${LOWERAPP}.desktop  # "can't find /usr/bin/vlc"
get_icon
patch_usr
get_apprun
cd ..
generate_type2_appimage

