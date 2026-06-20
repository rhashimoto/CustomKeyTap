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

To grant permission to read and write keyboard events, open macOS Privacy &
Security settings, open the Accessibility section, and add and enable
the program there.

Finally, [create a launch agent](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)
to automatically start and run in the background.
