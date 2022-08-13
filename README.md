# vimv

vimv is a terminal-based file rename utility that lets you easily bulk-rename files using Vim (or `$EDITOR`).

## Installing

1. For the current user:
   ```
   curl -s https://raw.githubusercontent.com/thameera/vimv/master/vimv > ~/bin/vimv && chmod 755 ~/bin/vimv
   ```
2. For the current system:
   ```
   sudo curl -s https://raw.githubusercontent.com/thameera/vimv/master/vimv > /usr/local/bin/vimv && sudo chmod 755 /usr/local/bin/vimv
   # OR #
   sudo PREFIX=/usr/local make install
   ```

Or simply copy the `vimv` file to a location in your `$PATH` and make it executable.

## Usage

1. Run `vimv` in a directory, its files will be presented in your editor.
2. Edit as desired.  e.g. search and replace a particular string.
3. Save and exit to rename your files.

Important: Do NOT delete or swap the lines while editing or unexpected things will occur.

## Other features

* To list only a group of files, you can pass them as an argument. eg: `vimv *.mp4`
* `vimv` uses the `$EDITOR` environment variable by default.
* Within a Git directory, vimv will use `git mv` (instead of `mv`) to rename the files.
* You can use `/some/path/filename` format to move a file elsewhere during renaming, automatically creating new directories before moving.

## Screencast

![alt text](screencast.gif "vimv in action")
