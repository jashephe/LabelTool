<img src="https://github.com/jashephe/LabelTool/wiki/images/icon.png" alt="LabelTool Icon" width="128">

# LabelTool

LabelTool is a macOS application for generating and printing labels on ZPL-compatible thermal printers. You can define label templates with predefined *fields*, which can are then filled in with tabular data from a file or the clipboard (e.g. from a spreadsheet). LabelTool can communicate with label printers that understand the common ZPL II protocol, and print multiple labels with a single click.

* Design custom label templates, with arbitrary sizes and characteristics (e.g. DPI)
* Connect to and print from multiple ZPL II-compatible printers
* Labels can consist of fixed text and any number of *fields*, which can be programmatically substituted
* Values for commonly-used *fields* (e.g. `$name` or `$initials`) can be set in preferences
* Includes a small selection of "computed" *fields*, such as the current date (`#today`) or a per-label [UUID](https://en.wikipedia.org/wiki/Universally_unique_identifier) (`#uuid`)
* Includes basic support for DataMatrix 2D barcodes; support for more symbologies is on the roadmap

## Screenshot

<img src="https://github.com/jashephe/LabelTool/wiki/images/main_window.png" alt="Main Application Window" width="808">

More screenshots are available [on the wiki](https://github.com/jashephe/LabelTool/wiki/Screenshots).

## Download

[Click here to download the latest release.](https://github.com/jashephe/LabelTool/releases/latest) LabelTool includes a rudimentary update notification mechanism, and will alert you when new versions are available.

## Issues and Feature Requests

If you run into any issues with LabelTool, or would like to request a new feature, please use [the GitHub Issues page](https://github.com/jashephe/LabelTool/issues).
