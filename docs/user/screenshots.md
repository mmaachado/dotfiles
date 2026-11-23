# Screenshots and recordings

Screenshots work like on a Mac, with Spectacle doing the capturing underneath.

| Keys | Does |
| --- | --- |
| ++meta+shift+3++ | Screenshot of everything (all displays) |
| ++meta+shift+4++ | Screenshot of a region: drag to select it |
| ++meta+shift+5++ | The capture toolbar |

## The capture toolbar

++meta+shift+5++ opens a toolbar at the bottom of the screen:

- **Everything**, **This display**, **Window** and **Region**: take a screenshot.
- **Record display** and **Record region**: start a screen recording. While
  it runs, the bar shows a red pill with the time; click it to stop.
- **Timer** (off, 5 s, 10 s), **Show pointer** and **Open folder**.

Screenshots are saved to `~/Pictures/Screenshots` as
`Screenshot YYYY-MM-DD at HH.MM.SS.png` and copied to the clipboard.
Recordings go to `~/Videos/Screencasts`.

## The thumbnail

After a capture, a thumbnail slides into the bottom-right corner for a few
seconds; it stays while you hover it.

- **Click** it to annotate the screenshot in droid Markup, or to play a recording.
- **Drag** it into an app (a chat, a document, a file manager) to drop the file there.
- The buttons on it show the file in its folder, move it to the trash, or dismiss it.

## droid Markup

droid Markup is droid's screenshot editor (a Kotlin app), installed with
`just apps-install`. It has:

- pen, highlighter, arrow, rectangle, ellipse and text, in eight colours and three sizes
- **pixelate**, to hide passwords, names and anything else that shouldn't be read
- **crop**

++ctrl+s++ saves over the screenshot, ++ctrl+shift+s++ saves a copy,
++ctrl+c++ copies the result, and ++ctrl+z++ / ++ctrl+shift+z++ undo and redo.
Until droid Markup is installed, the thumbnail opens Spectacle's editor.
