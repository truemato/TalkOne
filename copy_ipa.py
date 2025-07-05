#!/usr/bin/env python3
import shutil
import os

source = '/Users/hundlename/TALKONE_WITHCLAUDE/TalkOne-Project/build/ios/iphoneos/TalkOne.ipa'
destination = '/Users/hundlename/Desktop/TalkOne_v0.9.1_iOS_20250703.ipa'

try:
    shutil.copy2(source, destination)
    print(f"Successfully copied IPA to {destination}")
    print(f"File size: {os.path.getsize(destination)} bytes")
except Exception as e:
    print(f"Error copying IPA: {e}")