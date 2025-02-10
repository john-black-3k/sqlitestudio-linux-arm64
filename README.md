## SQLiteStudio Linux aarch64 build

This is the portable build of SQLiteStudio and is intended to be run on Linux Arm64 [UserLand Android app](https://play.google.com/store/apps/details?id=tech.ula).

To build  this I have created a bash script (`build_sqlitestudio_qt5.sh`) that closely follows the Github Action workflow [`lin_release.yml`](https://github.com/pawelsalawa/sqlitestudio/blob/3.4/.github/workflows/lin_release.yml) for the 3.4 branch of SQLiteStudio.

## Build script usage

To build the portable distribution yourself you need to put 2 files in the directory `/storage/internal/sqlite`:
- `sqlitestudio-3.4.16.zip`: the source code in ZIP format of the SQLiteStudio version configured in the build script via the `SQLITE_STUDIO_VERSION` variable. You can download the latest from the [SQLiteStudio releases page](https://github.com/pawelsalawa/sqlitestudio/releases).
- `sqlitestudio-dbg.sh` which you can find in this repository. This script will be copied to the portable folder and can be used to launch SQLiteStudio in debug mode.

Inside the script you can specify at the top:
- `SQLITE_STUDIO_VERSION`: as mentioned above, you need to download the source code of SQLiteStudio in ZIP format and put the ZIP in `/storage/internal/sqlite` directory
- `SQLITE_VERSION`: the build script will automatically download the specified SQLite version from the [sqlite3-sqls repository](https://github.com/pawelsalawa/sqlite3-sqls) and build SQLite and extensions for aarch64
- `PYTHON_VERSION`: the version of Python you have available on your Linux system; will be used to build the `ScriptingPython` plugin


