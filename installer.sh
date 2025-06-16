#!/usr/bin/env bash

DISTROBOX_CONTAINER="BeamMP"
BIN_FOLDER=$(realpath ~/.local/bin)
N=$'\n'

echo "Checking requirements..."
if ! ping -c 2 example.nl > /dev/null; then
  echo "ERROR: Not connected to the internet."
  exit 1
fi
if [ ! -e ~/.steam/steam/steamapps/common/BeamNG.drive/BinLinux/BeamNG.drive.x64 ]; then
  echo "ERROR: BeamNG is not available at the following path: $(realpath ~/.steam/steam/steamapps/common/BeamNG.drive/BinLinux/BeamNG.drive.x64)"
  exit 1
fi
if [ -e "$BIN_FOLDER/BeamMP" ] || [ -e "$BIN_FOLDER/BeamMP-Launcher" ]; then
  echo "BeamMP helper or proxy is already installed under '$BIN_FOLDER'. Please remove them before continuing."
  exit 1
fi
if ! command -v distrobox >/dev/null 2>&1; then
  echo "ERROR: Missing command; distrobox"
  exit 1
fi
if distrobox ls | grep "$DISTROBOX_CONTAINER" >/dev/null 2>&1; then
  echo "ERROR: Existing distrobox 'BeamMP', please delete this before running the script.You may use the following command:$N  distrobox rm --force $DISTROBOX_CONTAINER"
  exit 1
fi
echo "Starting script."

echo "Creating distrobox and file structure"
distrobox create -n "$DISTROBOX_CONTAINER"
mkdir -p "$BIN_FOLDER"

echo "Preparing and building BeamMP in distrobox";
SCRIPT=$(mktemp)
cat >"$SCRIPT" <<EOF
#!/usr/bin/env bash

# Installing dependancies
sudo dnf install -y libatomic fontconfig nss at-spi2-atk cups libXcomposite libXdamage libXrandr alsa-lib libxkbcommon @development-tools cmake vcpkg cpp-httplib-devel json-devel libcurl-devel git kernel-devel perl-IPC-Cmd perl-FindBin perl-File-Compare perl-File-Copy 

# Preparing source code and build tool
BUILD_DIR=\$(mktemp -d)
cd \$BUILD_DIR
git clone --depth=1 https://github.com/BeamMP/BeamMP-Launcher 
git clone --depth=1 https://github.com/Microsoft/vcpkg 
export VCPKG_ROOT=\$BUILD_DIR/vcpkg

# Building
cd BeamMP-Launcher
cmake . -B bin -DCMAKE_MAKE_PROGRAM=/usr/bin/make -DCMAKE_C_COMPILER=/usr/bin/gcc -DCMAKE_CXX_COMPILER=/usr/bin/g++ -DCMAKE_TOOLCHAIN_FILE=\$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake -DVCPKG_TARGET_TRIPLET=x64-linux
cmake --build bin --parallel
cp bin/BeamMP-Launcher "$BIN_FOLDER/BeamMP-Launcher"

cd
rm -rf \$BUILD_DIR
EOF

distrobox enter "$DISTROBOX_CONTAINER" -- bash "$SCRIPT"
rm "$SCRIPT"

cat >"$BIN_FOLDER/BeamMP" <<EOF
#!/usr/bin/env bash

trap "exit" INT TERM
trap "kill 0 && distrobox stop '$DISTROBOX_CONTAINER'" EXIT

exec distrobox enter "$DISTROBOX_CONTAINER" -- "$BIN_FOLDER/BeamMP-Launcher" &
exec ~/.steam/steam/steamapps/common/BeamNG.drive/BinLinux/BeamNG.drive.x64 2>&1 > /dev/null &

sleep 2
read -p "Press enter to stop beamng+beammp."
exit
EOF
chmod +x "$BIN_FOLDER/BeamMP"

echo "Installation complete! Launch BeamNG + BeamMP with the following command:$N  $BIN_FOLDER/BeamMP"
