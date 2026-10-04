#!/usr/bin/env bash
# Builds the FileSqueeze FFmpeg payload inside the pinned container.
# Inputs:  /recipe (this directory), /cache (source tarballs, reused between runs)
# Outputs: /out/<name>.zip (binaries + licences) and /out/<name>-sources.tar (corresponding source)
set -euo pipefail

HOST=x86_64-w64-mingw32
PREFIX=/opt/w64
WORK=/build
NAME=ffmpeg-8.1.3-win64-lgpl-filesqueeze
STAGE=$WORK/stage/$NAME
export SOURCE_DATE_EPOCH=1767225600 # 2026-01-01; fixed for reproducible archives
export CC=$HOST-gcc-posix CXX=$HOST-g++-posix AR=$HOST-ar RANLIB=$HOST-ranlib STRIP=$HOST-strip
export PKG_CONFIG_LIBDIR=$PREFIX/lib/pkgconfig PKG_CONFIG_PATH=
COMMON_FLAGS="-O2 -ffile-prefix-map=$WORK=. -I$PREFIX/include"
export CFLAGS="$COMMON_FLAGS" CXXFLAGS="$COMMON_FLAGS" LDFLAGS="-L$PREFIX/lib"
JOBS=$(nproc)

mkdir -p /cache "$WORK" "$PREFIX/include" "$PREFIX/lib/pkgconfig" /out

# Download every pinned archive and refuse anything with a different hash.
declare -A FILE
while read -r name file sha url; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    if [[ ! -f /cache/$file ]] || ! echo "$sha  /cache/$file" | sha256sum -c --status; then
        curl -fsSL -o "/cache/$file" "$url"
    fi
    echo "$sha  /cache/$file" | sha256sum -c --status || { echo "Checksum mismatch: $file" >&2; exit 1; }
    FILE[$name]=$file
done < /recipe/sources.lock

unpack() { # unpack <name> -> prints the source directory
    local dir=$WORK/src/$1
    rm -rf "$dir" && mkdir -p "$dir"
    tar -xf "/cache/${FILE[$1]}" -C "$dir" --strip-components=1
    echo "$dir"
}

cat > $WORK/cross.cmake <<EOF
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR AMD64)
set(CMAKE_C_COMPILER $CC)
set(CMAKE_CXX_COMPILER $CXX)
set(CMAKE_RC_COMPILER $HOST-windres)
set(CMAKE_FIND_ROOT_PATH $PREFIX /usr/$HOST)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF
cat > $WORK/cross.meson <<EOF
[binaries]
c = '$CC'
cpp = '$CXX'
ar = '$AR'
strip = '$STRIP'
windres = '$HOST-windres'
pkg-config = 'pkg-config'
[host_machine]
system = 'windows'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
EOF

# zlib: mov/mp4 compressed headers and the PNG decoder.
src=$(unpack zlib)
make -C "$src" -f win32/Makefile.gcc PREFIX=$HOST- CC="$CC" CFLAGS="$CFLAGS" -j"$JOBS" libz.a
install -m644 "$src/libz.a" $PREFIX/lib/
install -m644 "$src/zlib.h" "$src/zconf.h" $PREFIX/include/

# zimg: the zscale filter for HDR to SDR conversion.
src=$(unpack zimg)
(cd "$src" && ./autogen.sh >/dev/null && ./configure --host=$HOST --prefix=$PREFIX \
    --enable-static --disable-shared --disable-testapp --disable-example --disable-unit-test >/dev/null && \
    make -j"$JOBS" >/dev/null && make install >/dev/null)

# dav1d: AV1 decoding.
src=$(unpack dav1d)
meson setup "$src/build" "$src" --cross-file $WORK/cross.meson --prefix=$PREFIX --libdir=lib \
    --buildtype=release --default-library=static -Denable_tools=false -Denable_tests=false >/dev/null
ninja -C "$src/build" install >/dev/null

# libvpl: the dispatcher for Intel Quick Sync (h264_qsv).
src=$(unpack libvpl)
cmake -S "$src" -B "$src/build" -G Ninja -DCMAKE_TOOLCHAIN_FILE=$WORK/cross.cmake \
    -DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF -DINSTALL_EXAMPLES=OFF -DBUILD_EXPERIMENTAL=OFF >/dev/null
ninja -C "$src/build" install >/dev/null
# The static dispatcher is C++; its pkg-config file omits the runtime.
sed -i '/^Libs.private:/ s/$/ -lstdc++/' $PREFIX/lib/pkgconfig/vpl.pc
grep -q '^Libs.private:.*-lstdc++' $PREFIX/lib/pkgconfig/vpl.pc || echo 'Libs.private: -lstdc++' >> $PREFIX/lib/pkgconfig/vpl.pc

# nv-codec-headers and AMF: header-only; the drivers load at run time.
src=$(unpack nv-codec-headers)
make -C "$src" PREFIX=$PREFIX install >/dev/null
src=$(unpack amf-headers)
cp -r "$src/AMF" $PREFIX/include/

# FFmpeg: only the external libraries above. Native decoders, demuxers and filters stay.
src=$(unpack ffmpeg)
cd "$src"
./configure --prefix=/opt/ffmpeg --target-os=mingw32 --arch=x86_64 \
    --cross-prefix=$HOST- --cc="$CC" --cxx="$CXX" --pkg-config=pkg-config --pkg-config-flags=--static \
    --enable-shared --disable-static --enable-version3 --disable-autodetect --disable-debug \
    --disable-doc --disable-ffplay --disable-network \
    --disable-indevs --enable-indev=lavfi --disable-outdevs \
    --enable-w32threads --enable-zlib --enable-libzimg --enable-libdav1d \
    --enable-libvpl --enable-ffnvcodec --enable-nvenc --enable-amf \
    --enable-mediafoundation --enable-d3d11va --enable-dxva2 \
    --extra-cflags="$COMMON_FLAGS" \
    --extra-ldflags="-L$PREFIX/lib -static -Wl,--no-insert-timestamp"
# -static links the GCC, libstdc++ and winpthread runtimes into each DLL; Windows libraries stay dynamic.
make -j"$JOBS" >/dev/null
make install >/dev/null

# Stage binaries, configuration and licences.
rm -rf "$WORK/stage" && mkdir -p "$STAGE/bin" "$STAGE/licenses"
cp /opt/ffmpeg/bin/*.exe /opt/ffmpeg/bin/*.dll "$STAGE/bin/"
$STRIP "$STAGE"/bin/*
L=$STAGE/licenses
cp "$src/COPYING.LGPLv3" "$L/FFmpeg-COPYING.LGPLv3.txt"
cp "$src/COPYING.GPLv3" "$L/FFmpeg-COPYING.GPLv3.txt"
cp "$src/COPYING.LGPLv2.1" "$L/FFmpeg-COPYING.LGPLv2.1.txt"
cp "$src/LICENSE.md" "$L/FFmpeg-LICENSE.md"
cp "$WORK/src/zlib/LICENSE" "$L/zlib-LICENSE.txt"
cp "$WORK/src/zimg/COPYING" "$L/zimg-COPYING.txt"
cp "$WORK/src/dav1d/COPYING" "$L/dav1d-COPYING.txt"
cp "$WORK/src/libvpl/LICENSE" "$L/libvpl-LICENSE.txt"
sed -n '1,/\*\//p' "$WORK/src/nv-codec-headers/include/ffnvcodec/nvEncodeAPI.h" > "$L/nv-codec-headers-LICENSE.txt"
sed -n '1,/^$/p' "$WORK/src/amf-headers/AMF/core/Platform.h" > "$L/AMF-headers-LICENSE.txt"
cp /usr/share/doc/mingw-w64-common/copyright "$L/mingw-w64-runtime-COPYRIGHT.txt"
cp /usr/share/doc/gcc-mingw-w64-base/copyright "$L/gcc-runtime-COPYRIGHT.txt"

grep -o 'FFMPEG_CONFIGURATION "[^"]*"' "$src/config.h" | sed 's/^FFMPEG_CONFIGURATION //; s/"//g' > "$STAGE/build-configuration.txt"
{
    grep -m1 "^FROM" /recipe/Dockerfile
    dpkg-query -W -f='${Package} ${Version}\n' 'gcc-mingw-w64*' 'g++-mingw-w64*' 'binutils-mingw-w64*' 'mingw-w64*' nasm meson cmake
} > "$STAGE/toolchain.txt"
cp /recipe/sources.lock "$STAGE/sources.lock"
(cd "$STAGE/bin" && sha256sum * > ../SHA256SUMS)

# Deterministic archives.
cd "$WORK/stage"
find "$NAME" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
rm -f "/out/$NAME.zip"
find "$NAME" -type f | LC_ALL=C sort | zip -X -q -@ "/out/$NAME.zip"

# Corresponding source: every pinned archive plus this recipe.
SRC=$WORK/sources/$NAME-sources
rm -rf "$WORK/sources" && mkdir -p "$SRC/archives" "$SRC/recipe"
for name in "${!FILE[@]}"; do cp "/cache/${FILE[$name]}" "$SRC/archives/"; done
cp /recipe/* "$SRC/recipe/"
cd "$WORK/sources"
tar --sort=name --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 --numeric-owner \
    -cf "/out/$NAME-sources.tar" "$NAME-sources"
(cd /out && sha256sum "$NAME.zip" "$NAME-sources.tar" > "$NAME.sha256")
cat /out/$NAME.sha256
