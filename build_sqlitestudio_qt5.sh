#!/bin/bash

# Master: https://github.com/pawelsalawa/sqlitestudio/blob/master/.github/workflows/lin_release.yml

# 3.4 branch: https://github.com/pawelsalawa/sqlitestudio/blob/3.4/.github/workflows/lin_release.yml

# How to use this script:
# - create directory (for instance "wd") in /home/userland and cd to it
# - copy this script to the above directory
# - set this script as executable: chmod +x ...
# - launch the script: ./build_sqlitestudio_qt5.sh


set -eu

SQLITE_STUDIO_VERSION="3.4.16"
SQLITE_VERSION="3490000"
PYTHON_VERSION="3.10"
QT5_LIB_DIR="/usr/lib/aarch64-linux-gnu"
LIBSSL_DIR_URL="http://ports.ubuntu.com/pool/main/o/openssl/"
LIBSSL_DEB="libssl1.1_1.1.1f-1ubuntu2.23_arm64.deb"

function convert_int_ver() {
	# https://github.com/pawelsalawa/gh-action-scripts/blob/main/scripts/convert_int_ver.sh
	local INT_VER=$1

	local NUM0=${INT_VER:0:1}
	local NUM1=${INT_VER:1:2}
	local NUM2=${INT_VER:3:2}
	local NUM3=${INT_VER:5:2}
	NUM1=$((10#$NUM1))
	NUM2=$((10#$NUM2))
	NUM3=$((10#$NUM3))
	local SQLITE_DOT_VERSION="$NUM0.$NUM1.$NUM2"
	if [ $NUM3 -ne 0 ]; then
		SQLITE_DOT_VERSION="$SQLITE_DOT_VERSION.$NUM3"
	fi

	echo $SQLITE_DOT_VERSION
}

# delete outputs
rm -rf sqlite* ext*

# Pre-download SQLite vanilla sourcecode
SQLITE_DOT_VERSION=$(convert_int_ver $SQLITE_VERSION)
echo "SQLITE_DOT_VERSION=$SQLITE_DOT_VERSION"

curl -L https://github.com/pawelsalawa/sqlite3-sqls/releases/download/v$SQLITE_DOT_VERSION/sqlite3-amalgamation-$SQLITE_VERSION.zip --output sqlite3-amalgamation-$SQLITE_VERSION.zip
curl -L https://github.com/pawelsalawa/sqlite3-sqls/releases/download/v$SQLITE_DOT_VERSION/sqlite3-extensions-src-$SQLITE_VERSION.zip --output sqlite3-extensions-src-$SQLITE_VERSION.zip

mkdir sqlite3-src
unzip sqlite3-amalgamation-$SQLITE_VERSION.zip -d sqlite3-src

mkdir ext-src
unzip sqlite3-extensions-src-$SQLITE_VERSION.zip -d ext-src

pwd

# Compile SQLite 3
cd sqlite3-src
echo "Compiling SQLite 3 library and CLI executable"

set -x
gcc sqlite3.c -lpthread -ldl -lm -Os -fpic -shared -o libsqlite3.so \
                    -DSQLITE_ENABLE_UPDATE_DELETE_LIMIT \
                    -DSQLITE_ENABLE_DBSTAT_VTAB \
                    -DSQLITE_ENABLE_BYTECODE_VTAB \
                    -DSQLITE_ENABLE_COLUMN_METADATA \
                    -DSQLITE_ENABLE_EXPLAIN_COMMENTS \
                    -DSQLITE_ENABLE_FTS3 \
                    -DSQLITE_ENABLE_FTS4 \
                    -DSQLITE_ENABLE_FTS5 \
                    -DSQLITE_ENABLE_GEOPOLY \
                    -DSQLITE_ENABLE_JSON1 \
                    -DSQLITE_ENABLE_RTREE \
                    -DSQLITE_ENABLE_MATH_FUNCTIONS

gcc shell.c sqlite3.c -I. -lpthread -ldl -lm -lz -lreadline -lncurses \
                    -Os -o sqlite3 \
                    -DSQLITE_ENABLE_UPDATE_DELETE_LIMIT \
                    -DSQLITE_ENABLE_DBSTAT_VTAB \
                    -DSQLITE_ENABLE_BYTECODE_VTAB \
                    -DSQLITE_ENABLE_COLUMN_METADATA \
                    -DSQLITE_ENABLE_EXPLAIN_COMMENTS \
                    -DSQLITE_ENABLE_FTS3 \
                    -DSQLITE_ENABLE_FTS4 \
                    -DSQLITE_ENABLE_FTS5 \
                    -DSQLITE_ENABLE_GEOPOLY \
                    -DSQLITE_ENABLE_JSON1 \
                    -DSQLITE_ENABLE_RTREE \
                    -DSQLITE_ENABLE_MATH_FUNCTIONS \
                    -DHAVE_READLINE   
set +x

strip libsqlite3.so
strip sqlite3
ls -l

cd .. 
pwd

# Install SQLite 3
sudo rm -f /usr/local/lib/libsqlite* /usr/local/include/sqlite*

sudo cp -P sqlite3-src/libsqlite3.so* /usr/local/lib/
sudo cp sqlite3-src/*.h /usr/local/include/
ls -l /usr/local/lib/libsqlite3*
ls -l /usr/local/include/sqlite*

pwd

# Compile additional SQLite3 extensions
mkdir ext
cd ext-src

FLAGS="-ldl -Os -fpic -shared -Imisc -I/usr/local/include -L/usr/local/lib -lsqlite3"
set -x
for f in compress; do
	gcc misc/$f.c $FLAGS -lz -o ../ext/$f.so
done
for f in csv decimal eval ieee754 percentile rot13 series sqlar uint uuid zorder; do
	gcc misc/$f.c $FLAGS -o ../ext/$f.so
done
for f in icu; do
	gcc icu/$f.c $FLAGS `pkg-config --libs --cflags icu-uc icu-io` -o ../ext/$f.so
done
set +x

ls -l ../ext/

cd ..
pwd

## Prepare SQLiteSudio for compilation
read -p "Prepare SQLiteStudio for compilation? (y/N) : " yn
case $yn in
    [Yy]* ) ;;
    * ) echo "Exiting."; exit;;
esac

cp -f /storage/internal/sqlite/sqlitestudio-$SQLITE_STUDIO_VERSION.zip .
unzip sqlitestudio-$SQLITE_STUDIO_VERSION.zip
cd sqlitestudio-$SQLITE_STUDIO_VERSION

# Prepare output dir
mkdir output output/build output/build/Plugins

# Compile SQLiteStudio3
cd output/build
pwd

read -p "Start compiling SQLiteStudio3? (y/N) : " yn
case $yn in
    [Yy]* ) ;;
    * ) echo "Exiting."; cd ../..; pwd; exit;;
esac

# installed apt packages: qtbase5-dev qtbase5-dev-tools qt5-qmake qt5-qmake-bin qt5-image-formats-plugin-pdf qt5-image-formats-plugins qtdeclarative5-dev qttools5-dev-tools libqt5svg5-dev qttools5-dev qtscript5-dev
# apt packages not required by build, but required later: libqt5waylandclient5-dev qtwayland5
/usr/lib/qt5/bin/qmake \
    CONFIG+=portable \
    ../../SQLiteStudio3
#    2>&1 | tee -a /storage/internal/sqlite/qmake_output.txt
#make -j 1 2>&1 | tee -a /storage/internal/sqlite/make_output.txt
make -j 4

cd ../../..
pwd

read -p "Start compiling Plugins? (y/N) : " yn
case $yn in
    [Yy]* ) ;;
    * ) echo "Exiting."; cd ../..; pwd; exit;;
esac

# link against python3.10 in ScriptingPython plugin (see below)
# this is done through qmake parameter in SQLiteStudio 3.4.14+
#cp -f /storage/internal/sqlite/ScriptingPython.pro sqlitestudio-$SQLITE_STUDIO_VERSION/Plugins/ScriptingPython/

# gcc: error: unrecognized command-line option '-msse4.1' 
# gcc: error: unrecognized command-line option '-msse4.2' 
# gcc: error: unrecognized command-line option '-maes'
# remove aarch64 unsupported QMAKE_CFLAGS
# EDIT: not necessary anymore in SQLiteStudio 3.4.16+, as the flags are now conditional
#cp -f /storage/internal/sqlite/DbSqliteWx.pro sqlitestudio-$SQLITE_STUDIO_VERSION/Plugins/DbSqliteWx/

cd sqlitestudio-$SQLITE_STUDIO_VERSION

# Compile Plugins
cd output/build/Plugins
pwd

# installed apt packages: libssl-dev
/usr/lib/qt5/bin/qmake \
    CONFIG+=portable \
    "PYTHON_VERSION = $PYTHON_VERSION" \
    "INCLUDEPATH += /usr/include/python$PYTHON_VERSION" \
    "LIBS += -L/usr/lib/aarch64-linux-gnu" \
     ../../../Plugins
make -j 1

echo "Compilation finished."
cd ../../../..
pwd


INITIAL_DIR=`pwd`
echo "Initial dir: $INITIAL_DIR"

read -p "Start creating portable distribution? (y/N) : " yn
case $yn in
    [Yy]* ) ;;
    * ) echo "Exiting."; exit;;
esac

rm -rf ./usr $LIBSSL_DEB

cd sqlitestudio-$SQLITE_STUDIO_VERSION

rm -rf output/SQLiteStudio/extensions
rm -rf output/portable

# Copy SQLite extensions to output dir
echo "Copy SQLite extensions to output dir"
cp -R ../ext output/SQLiteStudio/extensions

# Prepare portable dir
echo "Prepare portable dir"
cd output
mkdir portable
cp -R SQLiteStudio portable/

read -p "Include SQLiteStudio version in portable dir name? (y/N) : " yn
case $yn in
    [Yy]* ) PORTABLE_DIR_VERSION="Y"; mv portable/SQLiteStudio portable/SQLiteStudio-$SQLITE_STUDIO_VERSION; cd portable/SQLiteStudio-$SQLITE_STUDIO_VERSION ;;
    * ) PORTABLE_DIR_VERSION="N"; cd portable/SQLiteStudio ;;
esac

PORTABLE_DIR=`pwd`
echo "Portable dir: $PORTABLE_DIR"

# Copy SQLite3 to portable dir
echo "Copy SQLite3 to portable dir"
cp -P /usr/local/lib/libsqlite3.so* lib/

# Copy SQLite3 shell to portable dir
echo "Copy SQLite3 shell to portable dir"
cp -P $INITIAL_DIR/sqlite3-src/sqlite3 .

# Copy "sqlitestudio-dbg.sh" to portable dir
echo "Copy 'sqlitestudio-dbg.sh' to portable dir and chmod +x it"
cp /storage/internal/sqlite/sqlitestudio-dbg.sh .
chmod +x sqlitestudio-dbg.sh

# Copy SQLCipher's libcrypto to portable dir
echo "Copy SQLCipher's libcrypto to portable dir"
cd $PORTABLE_DIR
LIBCRYPTO=$(ldd plugins/libDbSqliteCipher.so | grep crypto | awk '{print $3}')
REAL_LIBCRYPTO=$(readlink -e $LIBCRYPTO)
cp -P $REAL_LIBCRYPTO lib/$(basename -- $LIBCRYPTO)

# Copy Qt's libcrypto and libssl to portable dir (#4577)
echo "Copy Qt's libcrypto and libssl to portable dir (#4577)"
cd $INITIAL_DIR
wget ${LIBSSL_DIR_URL}${LIBSSL_DEB}
dpkg-deb -xv $LIBSSL_DEB .
cp ./usr/lib/aarch64-linux-gnu/libssl.so.1.1 $PORTABLE_DIR/lib/
cp ./usr/lib/aarch64-linux-gnu/libcrypto.so.1.1 $PORTABLE_DIR/lib/

# Copy Qt to portable dir
echo "Copy Qt to portable dir"
cd $PORTABLE_DIR
cp -P $QT5_LIB_DIR/libQt5Core.so* lib/
cp -P $QT5_LIB_DIR/libQt5DBus.so* lib/
cp -P $QT5_LIB_DIR/libQt5Concurrent.so* lib/
cp -P $QT5_LIB_DIR/libQt5Gui.so* lib/
cp -P $QT5_LIB_DIR/libQt5Network.so* lib/
cp -P $QT5_LIB_DIR/libQt5PrintSupport.so* lib/
cp -P $QT5_LIB_DIR/libQt5Qml.so* lib/
cp -P $QT5_LIB_DIR/libQt5WaylandClient.so* lib/
cp -P $QT5_LIB_DIR/libQt5Widgets.so* lib/
cp -P $QT5_LIB_DIR/libQt5Xml.so* lib/
cp -P $QT5_LIB_DIR/libQt5Svg.so* lib/
cp -P $QT5_LIB_DIR/libQt5XcbQpa.so* lib/
cp -P $QT5_LIB_DIR/libicui18n.so* lib/
cp -P $QT5_LIB_DIR/libicuuc.so* lib/
cp -P $QT5_LIB_DIR/libicudata.so* lib/

# Copy Qt plugins to portable dir
echo "Copy Qt plugins to portable dir"
cd $PORTABLE_DIR
mkdir platforms imageformats iconengines printsupport platformthemes platforminputcontexts wayland-decoration-client wayland-graphics-integration-client wayland-shell-integration
cp -P $QT5_LIB_DIR/qt5/plugins/platforms/libqxcb.so platforms/libqxcb.so
cp -P $QT5_LIB_DIR/qt5/plugins/platforms/libqwayland-*.so platforms/
cp -P $QT5_LIB_DIR/qt5/plugins/imageformats/libqgif.so imageformats/libqgif.so
cp -P $QT5_LIB_DIR/qt5/plugins/imageformats/libqicns.so imageformats/libqicns.so
cp -P $QT5_LIB_DIR/qt5/plugins/imageformats/libqico.so imageformats/libqico.so
cp -P $QT5_LIB_DIR/qt5/plugins/imageformats/libqjpeg.so imageformats/libqjpeg.so
cp -P $QT5_LIB_DIR/qt5/plugins/imageformats/libqsvg.so imageformats/libqsvg.so
cp -P $QT5_LIB_DIR/qt5/plugins/imageformats/libqtga.so imageformats/libqtga.so
cp -P $QT5_LIB_DIR/qt5/plugins/imageformats/libqtiff.so imageformats/libqtiff.so
cp -P $QT5_LIB_DIR/qt5/plugins/iconengines/libqsvgicon.so iconengines/libqsvgicon.so
cp -P $QT5_LIB_DIR/qt5/plugins/printsupport/libcupsprintersupport.so printsupport/libcupsprintersupport.so
cp -P $QT5_LIB_DIR/qt5/plugins/platformthemes/libqgtk3.so platformthemes/libqgtk3.so
cp -P $QT5_LIB_DIR/qt5/plugins/platforminputcontexts/libcomposeplatforminputcontextplugin.so platforminputcontexts/libcomposeplatforminputcontextplugin.so
cp -P $QT5_LIB_DIR/qt5/plugins/wayland-decoration-client/*.so wayland-decoration-client/
cp -P $QT5_LIB_DIR/qt5/plugins/wayland-graphics-integration-client/*.so wayland-graphics-integration-client/
cp -P $QT5_LIB_DIR/qt5/plugins/wayland-shell-integration/*.so wayland-shell-integration/

# Fix dependency paths
echo "Fix dependency paths"
cd $PORTABLE_DIR
set -x
set +e
chrpath -k -r \$ORIGIN/../lib   platforms/*.so imageformats/*.so iconengines/*.so printsupport/*.so platformthemes/*.so plugins/*.so wayland-*/*.so 2>&1 >/dev/null
chrpath -k -r \$ORIGIN          lib/libicu*.*.*
chrpath -k -r \$ORIGIN          lib/libcoreSQLiteStudio.so lib/libguiSQLiteStudio.so 2>&1 >/dev/null
chrpath -k -r \$ORIGIN/lib      sqlitestudio 2>&1 >/dev/null
chrpath -k -r \$ORIGIN/lib      sqlitestudiocli 2>&1 >/dev/null
chrpath -k -l platforms/*.so imageformats/*.so iconengines/*.so printsupport/*.so platformthemes/*.so plugins/*.so wayland-*/*.so
chrpath -k -l lib/libicu*.*.*
chrpath -k -l lib/libcoreSQLiteStudio.so lib/libguiSQLiteStudio.so
chrpath -l sqlitestudio
chrpath -l sqlitestudiocli
set +x
set -e

# Final preparations for packaging
echo "Final preparations for packaging"
mkdir $PORTABLE_DIR/assets
cd $INITIAL_DIR/sqlitestudio-$SQLITE_STUDIO_VERSION
cp SQLiteStudio3/guiSQLiteStudio/img/sqlitestudio_256.png $PORTABLE_DIR/assets/appicon.png
cp SQLiteStudio3/guiSQLiteStudio/img/sqlitestudio.svg $PORTABLE_DIR/assets/appicon.svg

# Final preparations for packaging (cont)
echo "Final preparations for packaging (cont)"
cd $PORTABLE_DIR
cp `ldd sqlitestudiocli | grep readline | awk '{print $3}'` lib/
cp `ldd lib/libreadline* | grep tinfo | awk '{print $3}'` lib/
strip lib/*.so sqlitestudio sqlitestudiocli platforms/*.so imageformats/*.so iconengines/*.so printsupport/*.so platformthemes/*.so plugins/*.so
# These may have no initial rpath/runpath so chrpath does not work on them
patchelf --set-rpath '$ORIGIN' \
    lib/libQt5Core.so.*.*.* \
    lib/libreadline*

# Assemble portable package
echo "Assemble portable package"
cd $PORTABLE_DIR/..
ARCHIVE_NAME="sqlitestudio-aarch64-$SQLITE_STUDIO_VERSION"
case $PORTABLE_DIR_VERSION in
    [Yy]* )  tar cf $ARCHIVE_NAME.tar SQLiteStudio-$SQLITE_STUDIO_VERSION ;;
    * ) tar cf $ARCHIVE_NAME.tar SQLiteStudio ;;
esac
xz -z $ARCHIVE_NAME.tar
pwd
ls -l


echo "Done."
pwd
