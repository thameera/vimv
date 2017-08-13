# vimv

vimv is a terminal-based file rename utility that lets you easily mass-rename files using Vim.

## Installing

```
curl https://raw.githubusercontent.com/thameera/vimv/master/vimv > ~/bin/vimv && chmod +755 ~/bin/vimv
```

Or simply copy the `vimv` file to a location in your `$PATH` and make it executable.

## Usage

1. Go to a directory and enter `vimv`. A Vim window will be opened with names of all files.
2. Use Vim's text editing features to edit the names of files. For example, search and replace a particular string, or use visual selection to delete a block.
3. Save and exit. Your files should be renamed now.

## Screencast

![alt text](screencast.gif "vimv in action")

## Gotchas

Don't delete or swap the lines while in Vim or things will get ugly.
