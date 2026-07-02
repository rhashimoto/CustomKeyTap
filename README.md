# CustomKeyTap
This is a macOS key event tap utility I wrote for myself because I wanted a
similar experience using the keyboard on my MacBook as I have with the
mechanical keyboard with custom firmware I use on my Mac mini.

This command-line program implements:

* [home row modifiers](https://precondition.github.io/home-row-mods)
  * permissive hold
  * flow tap
* a [momentary layer](https://docs.qmk.fm/feature_layers)
* [Caps Word](https://docs.qmk.fm/features/caps_word)

The mappings are in the source code so any changes require an edit and
rebuild.

## Installation
Put the executable in a location of your choice. I create the directory
`~/Applications/CustomKeyTap/` and move/copy it there.

If you are copying the executable from another Mac, you may need to
disable the quarantine bit with:

`xattr -d com.apple.quarantine /path/to/file`

Any program that uses a `CGEventTapLocation.cgSessionEventTap` needs
user permission. To grant this permission, open macOS Privacy & Security
settings, open the Accessibility section, and enable the parent process
program there. The first time the CustomKeyTap is run without permission,
macOS will typically add a disabled entry to Accessibility for the parent process
program which you can then simply enable, but if not then add it manually.
The parent process program will be
Terminal if you run CustomKeyTap from Terminal, but if you start it
with [launchd](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html) then CustomKeyTap itself will be the parent process. Note that if
you overwrite your CustomKeyTap with a new version, you may need to
remove it completely from Accessibility and then re-add and enable
it to re-establish the permission.

Programs with the Accessibility permission can read most of your user interface inputs,
including your keystrokes. You should seriously weigh the benefits and
risks of running software that requires this permission.

## Command line build
`xcodebuild -project CustomKeyTap.xcodeproj -scheme CustomKeyTap -configuration Release build`

Insert the option `-derivedDataPath ./` to build in the project directory.
