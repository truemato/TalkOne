#!/usr/bin/env python3
import os
import subprocess
import shutil
from datetime import datetime

# Set up paths
project_path = "/Users/hundlename/TALKONE_WITHCLAUDE/TalkOne-Project"
ios_path = os.path.join(project_path, "ios")
build_path = os.path.join(project_path, "build")
desktop_path = os.path.expanduser("~/Desktop")
ipa_name = "TalkOne_v0.9.1_iOS_20250703.ipa"

print("Starting IPA build process...")

# Change to project directory
os.chdir(project_path)

# Clean previous builds
print("Cleaning previous builds...")
subprocess.run(["flutter", "clean"], check=True)

# Get dependencies
print("Getting Flutter dependencies...")
subprocess.run(["flutter", "pub", "get"], check=True)

# Build iOS app
print("Building iOS app...")
subprocess.run(["flutter", "build", "ios", "--release"], check=True)

# Navigate to iOS directory
os.chdir(ios_path)

# Archive the app
print("Creating archive...")
archive_path = os.path.join(build_path, "TalkOne.xcarchive")
subprocess.run([
    "xcodebuild",
    "-workspace", "Runner.xcworkspace",
    "-scheme", "Runner",
    "-configuration", "Release",
    "-archivePath", archive_path,
    "archive",
    "DEVELOPMENT_TEAM=658363YSD7"
], check=True)

# Export IPA
print("Exporting IPA...")
export_path = os.path.join(build_path, "ipa")
subprocess.run([
    "xcodebuild",
    "-exportArchive",
    "-archivePath", archive_path,
    "-exportPath", export_path,
    "-exportOptionsPlist", "ExportOptions.plist"
], check=True)

# Copy IPA to desktop
print("Copying IPA to desktop...")
source_ipa = os.path.join(export_path, "Runner.ipa")
dest_ipa = os.path.join(desktop_path, ipa_name)
shutil.copy2(source_ipa, dest_ipa)

print(f"IPA build complete! File saved to {dest_ipa}")