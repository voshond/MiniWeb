#  MiniWeb

This is a small project attempting to recreate Safari's 'Reader Mode' in WatchKit.

Currently supports:

* a
* img
* b
* br
* q, blockquote
* p
* h1
* h2
* h3
* h4

## Edge Cases
Not all websites will work with the article detection. In an attempt to combat this, `forbiddenClasses` has been defined in the `InterfaceController.swift`. This array contains all the classes which should be ignored
