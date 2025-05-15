# ChoreWars

ChoreWars is a Flutter application that helps households manage chores and tasks while adding a competitive, gamified element to household responsibilities. The app allows users to create households, assign and complete tasks, earn points, and track statistics.

## Quick Setup for Mac (with VS Code already installed)

If you already have VS Code installed on your Mac and want to get ChoreWars running quickly:

1. **Install Flutter SDK** via Homebrew:
   ```
   brew install --cask flutter
   ```

2. **Verify Flutter installation**:
   ```
   flutter doctor
   ```
   Follow any recommendations to complete the setup.

3. **Install Flutter extension in VS Code**:
   - Open VS Code
   - Press `Cmd+Shift+X` to open Extensions
   - Search for "Flutter" and install

4. **Install Android Studio** for the emulator:
   - Download from [Android Studio website](https://developer.android.com/studio)
   - Install and run the setup wizard with default options
   - Open Android Studio > More Actions > AVD Manager > Create Virtual Device

5. **Clone and run ChoreWars**:
   ```
   git clone https://github.com/ninjinodkhuu/chorewars.git
   cd chorewars
   flutter pub get
   flutter run
   ```

For more detailed instructions, refer to the full setup guides below.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Setup Guide for Mac](#setup-guide-for-mac)
   - [Install Flutter](#install-flutter)
   - [Install Android Studio](#install-android-studio)
   - [Set Up Android Emulator](#set-up-android-emulator)
   - [Install VS Code](#install-vs-code-mac)
3. [Setup Guide for Windows](#setup-guide-for-windows)
   - [Install Flutter](#install-flutter-windows)
   - [Install Android Studio](#install-android-studio-windows)
   - [Set Up Android Emulator](#set-up-android-emulator-windows)
   - [Install VS Code](#install-vs-code-windows)
4. [Setup Guide for Linux](#setup-guide-for-linux)
   - [Install Flutter](#install-flutter-linux)
   - [Install Android Studio](#install-android-studio-linux)
   - [Set Up Android Emulator](#set-up-android-emulator-linux)
   - [Install VS Code](#install-vs-code-linux)
5. [Project Setup](#project-setup)
   - [Clone the Repository](#clone-the-repository)
   - [Install Dependencies](#install-dependencies)
   - [Firebase Configuration](#firebase-configuration)
6. [Running the Application](#running-the-application)
   - [Start the Emulator](#start-the-emulator)
   - [Run the ChoreWars App](#run-the-chorewars-app)
   - [Run in VS Code](#run-in-vs-code)
7. [Troubleshooting](#troubleshooting)
   - [Common Issues on Mac](#common-issues-and-solutions)
   - [Common Issues on Windows](#common-issues-and-solutions-windows)
   - [Common Issues on Linux](#common-issues-and-solutions-linux)
8. [Additional Resources](#additional-resources)

## Prerequisites

### Mac Requirements
- Mac with macOS 10.15 (Catalina) or later
- At least 8GB of RAM (16GB recommended)
- At least 20GB of free disk space
- Internet connection for downloading resources
- Basic familiarity with terminal commands

### Windows Requirements
- Windows 10 or later (64-bit)
- At least 8GB of RAM (16GB recommended)
- At least 20GB of free disk space
- Internet connection for downloading resources
- Basic familiarity with command prompt or PowerShell

### Linux Requirements
- Ubuntu 20.04 LTS or later (64-bit) (other distributions also supported)
- At least 8GB of RAM (16GB recommended)
- At least 20GB of free disk space
- Internet connection for downloading resources
- Basic familiarity with terminal commands

## Setup Guide for Mac

### Install Flutter

1. Download the Flutter SDK from the [Flutter website](https://docs.flutter.dev/get-started/install/macos)
   - You can download the .zip file directly or use Homebrew:
   ```
   brew install --cask flutter
   ```

2. Extract the downloaded ZIP file to a desired location (if downloaded manually):
   ```
   cd ~/development
   unzip ~/Downloads/flutter_macos_3.16.0-stable.zip
   ```

3. Add Flutter to your PATH:
   ```
   export PATH="$PATH:`pwd`/flutter/bin"
   ```

4. Add the above line to your shell profile (e.g., `~/.zshrc` or `~/.bash_profile`) to make it permanent:
   ```
   echo 'export PATH="$PATH:~/development/flutter/bin"' >> ~/.zshrc
   ```
   (Adjust the path according to where you extracted Flutter)

5. Verify the installation:
   ```
   flutter doctor
   ```
   This command checks your environment and displays a report of the status of your Flutter installation.

### Install Android Studio

1. Download Android Studio from the [Android Studio website](https://developer.android.com/studio)

2. Install Android Studio:
   - Open the downloaded .dmg file
   - Drag Android Studio to the Applications folder
   - Open Android Studio from the Applications folder

3. Complete the setup wizard:
   - Select "Standard" installation when prompted
   - Follow the prompts to install the Android SDK, Android SDK Platform-Tools, and Android SDK Build-Tools

4. Install the Flutter and Dart plugins:
   - Open Android Studio
   - Go to Android Studio > Settings > Plugins (or Preferences > Plugins)
   - Search for "Flutter" and click "Install"
   - When prompted to install the Dart plugin, click "Yes"
   - Restart Android Studio when the installation completes

### Set Up Android Emulator

1. Open Android Studio

2. Click on "More Actions" or "Configure" from the welcome screen, then select "AVD Manager" (Android Virtual Device Manager)

3. Click on "+ Create Virtual Device"

4. Select a device definition (e.g., Pixel 6)

5. Select a system image:
   - Choose a recommended system image (e.g., API 34 - Android 14.0)
   - If the system image isn't already downloaded, click "Download" next to the image name
   - Wait for the download and installation to complete
   - Click "Next"

6. Configure the AVD:
   - Give your virtual device a name
   - Adjust settings as necessary (default settings are usually fine)
   - Click "Finish"

7. Verify Flutter can detect the emulator:
   ```
   flutter devices
   ```
   Your newly created emulator should be listed.

### Install VS Code (Mac)

1. Download Visual Studio Code from the [VS Code website](https://code.visualstudio.com/)

2. Open the downloaded .dmg file

3. Drag Visual Studio Code.app to the Applications folder

4. Launch VS Code from your Applications folder

5. Install the Flutter and Dart extensions:
   - Open VS Code
   - Go to Extensions view (Cmd+Shift+X)
   - Search for "Flutter" and click "Install"
   - This will also install the Dart extension

6. Verify Flutter extension installation:
   - Open Command Palette (Cmd+Shift+P)
   - Type "Flutter" and verify Flutter commands are available

## Setup Guide for Windows

### Install Flutter (Windows) {#install-flutter-windows}

1. Download the Flutter SDK from the [Flutter website](https://docs.flutter.dev/get-started/install/windows)
   - Download the .zip file

2. Extract the downloaded ZIP file to a desired location (avoid paths with spaces or special characters):
   ```powershell
   Expand-Archive -Path C:\path\to\flutter_windows_3.16.0-stable.zip -DestinationPath C:\dev
   ```

3. Add Flutter to your PATH:
   - Search for "Environment Variables" in Windows search
   - Click "Edit the system environment variables"
   - Click "Environment Variables" button
   - Under "User variables", select "Path" and click "Edit"
   - Click "New" and add the full path to the `flutter\bin` directory (e.g., `C:\dev\flutter\bin`)
   - Click "OK" on all dialogs

4. Verify the installation by opening a new PowerShell window:
   ```powershell
   flutter doctor
   ```

### Install Android Studio (Windows) {#install-android-studio-windows}

1. Download Android Studio from the [Android Studio website](https://developer.android.com/studio)

2. Run the installer and follow the installation wizard:
   - Check the boxes for "Android SDK", "Android SDK Platform", and "Android Virtual Device"
   - Follow the prompts to install

3. Install the Flutter and Dart plugins:
   - Open Android Studio
   - Navigate to File > Settings > Plugins
   - Search for "Flutter" and click "Install"
   - When prompted to install the Dart plugin, click "Yes"
   - Restart Android Studio when the installation completes

### Set Up Android Emulator (Windows) {#set-up-android-emulator-windows}

1. Open Android Studio

2. Click on "More Actions" or "Configure" from the welcome screen, then select "AVD Manager"

3. Click on "+ Create Virtual Device"

4. Select a device definition (e.g., Pixel 6)

5. Select a system image:
   - Choose a recommended system image (e.g., API 34 - Android 14.0)
   - If the system image isn't already downloaded, click "Download" next to the image name
   - Wait for the download and installation to complete
   - Click "Next"

6. Configure the AVD:
   - Give your virtual device a name
   - Adjust settings as necessary (default settings are usually fine)
   - Click "Finish"

7. Verify Flutter can detect the emulator:
   ```powershell
   flutter devices
   ```

### Install VS Code (Windows) {#install-vs-code-windows}

1. Download Visual Studio Code from the [VS Code website](https://code.visualstudio.com/)

2. Run the installer and follow the installation wizard
   - Enable "Add to PATH" option during installation

3. Install Flutter and Dart extensions:
   - Open VS Code
   - Go to Extensions view (Ctrl+Shift+X)
   - Search for "Flutter" and click "Install"
   - This will also install the Dart extension

4. Verify Flutter extension installation:
   - Open Command Palette (Ctrl+Shift+P)
   - Type "Flutter" and verify Flutter commands are available

## Setup Guide for Linux

### Install Flutter (Linux) {#install-flutter-linux}

1. Download the Flutter SDK from the [Flutter website](https://docs.flutter.dev/get-started/install/linux)
   - You can download the .tar.xz file directly or use snap:
   ```bash
   sudo snap install flutter --classic
   ```

2. If downloaded manually, extract the file:
   ```bash
   mkdir -p ~/development
   cd ~/development
   tar xf ~/Downloads/flutter_linux_3.16.0-stable.tar.xz
   ```

3. Add Flutter to your PATH:
   ```bash
   export PATH="$PATH:~/development/flutter/bin"
   ```

4. Add the above line to your shell profile (e.g., `~/.bashrc`) to make it permanent:
   ```bash
   echo 'export PATH="$PATH:~/development/flutter/bin"' >> ~/.bashrc
   source ~/.bashrc
   ```

5. Verify the installation:
   ```bash
   flutter doctor
   ```

### Install Android Studio (Linux) {#install-android-studio-linux}

1. Download Android Studio from the [Android Studio website](https://developer.android.com/studio)

2. Extract the downloaded file:
   ```bash
   tar -xzf android-studio-*.tar.gz -C ~/
   ```

3. Run the installation script:
   ```bash
   cd ~/android-studio/bin
   ./studio.sh
   ```

4. Complete the setup wizard:
   - Select "Standard" installation when prompted
   - Follow the prompts to install the Android SDK and related tools

5. Install the Flutter and Dart plugins:
   - Open Android Studio
   - Go to File > Settings > Plugins
   - Search for "Flutter" and click "Install"
   - When prompted to install the Dart plugin, click "Yes"
   - Restart Android Studio when the installation completes

### Set Up Android Emulator (Linux) {#set-up-android-emulator-linux}

1. Open Android Studio

2. Click on "More Actions" or "Configure" from the welcome screen, then select "AVD Manager"

3. Click on "+ Create Virtual Device"

4. Select a device definition (e.g., Pixel 6)

5. Select a system image:
   - Choose a recommended system image (e.g., API 34 - Android 14.0)
   - If the system image isn't already downloaded, click "Download" next to the image name
   - Wait for the download and installation to complete
   - Click "Next"

6. Configure the AVD:
   - Give your virtual device a name
   - Adjust settings as necessary (default settings are usually fine)
   - Click "Finish"

7. Verify Flutter can detect the emulator:
   ```bash
   flutter devices
   ```

### Install VS Code (Linux) {#install-vs-code-linux}

1. Install Visual Studio Code:
   - For Ubuntu/Debian:
   ```bash
   sudo apt update
   sudo apt install software-properties-common apt-transport-https wget
   wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add -
   sudo add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"
   sudo apt update
   sudo apt install code
   ```
   - For Snap-supported distributions:
   ```bash
   sudo snap install code --classic
   ```

2. Install Flutter and Dart extensions:
   - Open VS Code
   - Go to Extensions view (Ctrl+Shift+X)
   - Search for "Flutter" and click "Install"
   - This will also install the Dart extension

3. Verify Flutter extension installation:
   - Open Command Palette (Ctrl+Shift+P)
   - Type "Flutter" and verify Flutter commands are available

## Project Setup

### Clone the Repository

1. Clone the ChoreWars repository using Git:
   ```
   git clone https://github.com/ninjinodkhuu/chorewars.git
   ```

2. Navigate to the project directory:
   ```
   cd chorewars
   ```

### Install Dependencies

1. Run Flutter pub get to install the project dependencies:
   ```
   flutter pub get
   ```

### Firebase Configuration

The ChoreWars app uses Firebase for authentication and data storage. Follow these steps to configure Firebase:

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)

2. Add an Android app to your Firebase project:
   - Click on "Add app" and select the Android icon
   - Enter the package name: `com.example.chore` (as specified in your app's build.gradle)
   - Register the app
   - Download the `google-services.json` file
   - Place the downloaded file in the `android/app/` directory of your Flutter project

3. Enable Firebase services:
   - Go to the Firebase Console
   - Navigate to your project
   - Enable Authentication (with Email/Password and Google Sign-In)
   - Enable Firestore Database
   - Set up Firestore Security Rules as needed

## Running the Application

### Start the Emulator

1. Open Android Studio

2. Open the AVD Manager from Tools > AVD Manager

3. Click the play button (▶️) next to your emulator to start it
   - Alternatively, you can start the emulator from the command line:
   ```
   flutter emulators --launch <emulator_id>
   ```
   (Replace `<emulator_id>` with your emulator's ID from `flutter emulators`)

### Run the ChoreWars App

1. Make sure your emulator is running

2. From the project directory, run:
   ```
   flutter run
   ```

3. Wait for the app to build and launch on the emulator

4. If you want to run the app in release mode (for better performance):
   ```
   flutter run --release
   ```

### Run in VS Code

1. Open the ChoreWars project in VS Code:
   ```
   code .
   ```
   (Run this command from the project directory)

2. Make sure your emulator is running (or connect a physical device)

3. Click on the "Run" tab in the sidebar (or press Ctrl+Shift+D / Cmd+Shift+D)

4. Select "Flutter" from the dropdown menu at the top

5. Click the green play button or press F5 to start debugging

6. VS Code will build and launch the app on your device/emulator

7. You can use VS Code's debug console to view logs and debug information

8. To stop the app, click the red stop button in the debug toolbar or press Shift+F5

## Troubleshooting

### Common Issues and Solutions

1. **Flutter doctor shows issues**
   - Follow the recommended steps provided by `flutter doctor` to resolve them
   - Make sure all necessary Android SDK components are installed

2. **Emulator fails to start**
   - Ensure virtualization is enabled in your BIOS
   - Check if you have enough free disk space
   - Try creating a new emulator with different specifications

3. **Build errors**
   - Run `flutter clean` followed by `flutter pub get`
   - Ensure your Flutter SDK is up to date with `flutter upgrade`

4. **Firebase connection issues**
   - Verify that the `google-services.json` file is correctly placed in the `android/app/` directory
   - Check internet connectivity
   - Ensure the Firebase project is properly set up with the correct services enabled

5. **SDK version mismatch**
   - Update your Flutter SDK to match the version specified in the pubspec.yaml file
   - Run `flutter --version` to check your current version

6. **Android Studio can't find Flutter SDK**
   - Go to Android Studio > Preferences > Languages & Frameworks > Flutter
   - Set the Flutter SDK path to where you installed it

### Common Issues and Solutions (Windows) {#common-issues-and-solutions-windows}

1. **Flutter doctor shows issues**
   - Run PowerShell as Administrator and execute the suggested fixes
   - Install any missing dependencies with their Windows installers

2. **Path issues**
   - Verify that Flutter is properly added to your PATH
   - Restart PowerShell or Command Prompt after updating PATH
   - Use `where flutter` command to check if Flutter is in your PATH

3. **Android emulator not starting**
   - Enable Hyper-V in Windows features
   - Make sure Windows Hypervisor Platform is enabled
   - Disable Hyper-V if using another virtualization tool like VirtualBox

4. **VS Code doesn't detect Flutter**
   - Restart VS Code after installing Flutter extension
   - Use Command Palette and run "Flutter: New Project" to verify installation

5. **Permission issues**
   - Run VS Code or Android Studio as Administrator
   - Check Windows Defender or antivirus settings that might block execution

6. **Gradle build failures**
   - Check if your Windows username has special characters which can cause path issues
   - Use shorter paths for your Flutter and project directories
   - Make sure Android SDK location doesn't contain spaces or special characters

### Common Issues and Solutions (Linux) {#common-issues-and-solutions-linux}

1. **Missing dependencies**
   - Run `flutter doctor` to identify missing dependencies
   - Install required packages with your distribution's package manager:
   ```bash
   sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev
   ```

2. **Permission denied errors**
   - Adjust file permissions with `chmod`:
   ```bash
   chmod +x ~/development/flutter/bin/flutter
   ```

3. **AVD acceleration issues**
   - Install KVM for hardware acceleration:
   ```bash
   sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
   sudo adduser $USER kvm
   sudo chown $USER /dev/kvm
   ```

4. **VS Code extension problems**
   - Remove and reinstall the Flutter extension
   - Check VS Code logs (Help > Toggle Developer Tools)

5. **Snap package issues**
   - If using snap, try installing Flutter manually instead
   - Make sure snap has correct permissions

6. **HAXM not supported**
   - Linux uses KVM instead of HAXM for acceleration
   - Ensure CPU supports virtualization and it's enabled in BIOS

## Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Android Studio User Guide](https://developer.android.com/studio/intro)
- [Visual Studio Code Documentation](https://code.visualstudio.com/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Flutter VS Code Extension Documentation](https://docs.flutter.dev/tools/vs-code)
- [Flutter & Firebase Guide](https://firebase.google.com/docs/flutter/setup)

---

For any other issues or questions, please contact the ChoreWars development team.
