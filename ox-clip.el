;;; ox-clip.el --- Formatted copy commands across platforms

;;; Commentary: This module copies selected regions in org-mode as formatted
;;; text on the clipboard that can be pasted into other applications.

;; For Windows the html-clip-w32.py script will be installed. It works pretty
;; well, but I noticed that the hyperlinks in the TOC to headings don't work,
;; and strike-through doesn't seem to work. I have no idea how to fix either
;; issue.

;; Mac OSX needs textutils and pbcopy, which should be installed.

;; Linux needs a relatively modern xclip.

;; There is one command: `formatted-copy' that should work across Windows, Mac
;; and Linux.

;;; Code:

(defvar ox-clip-w32-py "#!/usr/bin/env python
# Adapted from http://code.activestate.com/recipes/474121-getting-html-from-the-windows-clipboard/
# HtmlClipboard
# An interface to the \"HTML Format\" clipboard data format

__author__ = \"Phillip Piper (jppx1[at]bigfoot.com)\"
__date__ = \"2006-02-21\"
__version__ = \"0.1\"

import re
import win32clipboard

class HtmlClipboard:

    CF_HTML = None

    MARKER_BLOCK_OUTPUT = \
        \"Version:1.0\\r\\n\" \
        \"StartHTML:%09d\\r\\n\" \
        \"EndHTML:%09d\\r\\n\" \
        \"StartFragment:%09d\\r\\n\" \
        \"EndFragment:%09d\\r\\n\" \
        \"StartSelection:%09d\\r\\n\" \
        \"EndSelection:%09d\\r\\n\" \
        \"SourceURL:%s\\r\\n\"

    MARKER_BLOCK_EX = \
        \"Version:(\\S+)\\s+\" \
        \"StartHTML:(\\d+)\\s+\" \
        \"EndHTML:(\\d+)\\s+\" \
        \"StartFragment:(\\d+)\\s+\" \
        \"EndFragment:(\\d+)\\s+\" \
        \"StartSelection:(\\d+)\\s+\" \
        \"EndSelection:(\\d+)\\s+\" \
        \"SourceURL:(\\S+)\"
    MARKER_BLOCK_EX_RE = re.compile(MARKER_BLOCK_EX)

    MARKER_BLOCK = \
        \"Version:(\\S+)\\s+\" \
        \"StartHTML:(\\d+)\\s+\" \
        \"EndHTML:(\\d+)\\s+\" \
        \"StartFragment:(\\d+)\\s+\" \
        \"EndFragment:(\\d+)\\s+\" \
           \"SourceURL:(\\S+)\"
    MARKER_BLOCK_RE = re.compile(MARKER_BLOCK)

    DEFAULT_HTML_BODY = \
        \"<!DOCTYPE HTML PUBLIC \\\"-//W3C//DTD HTML 4.0 Transitional//EN\\\">\" \
        \"<HTML><HEAD></HEAD><BODY><!--StartFragment-->%s<!--EndFragment--></BODY></HTML>\"

    def __init__(self):
        self.html = None
        self.fragment = None
        self.selection = None
        self.source = None
        self.htmlClipboardVersion = None


    def GetCfHtml(self):
        \"\"\"
        Return the FORMATID of the HTML format
        \"\"\"
        if self.CF_HTML is None:
            self.CF_HTML = win32clipboard.RegisterClipboardFormat(\"HTML Format\")

        return self.CF_HTML


    def PutFragment(self, fragment, selection=None, html=None, source=None):
        \"\"\"
        Put the given well-formed fragment of Html into the clipboard.

        selection, if given, must be a literal string within fragment.
        html, if given, must be a well-formed Html document that textually
        contains fragment and its required markers.
        \"\"\"
        if selection is None:
            selection = fragment
        if html is None:
            html = self.DEFAULT_HTML_BODY % fragment
        if source is None:
            source = \"\"

        fragmentStart = html.index(fragment)
        fragmentEnd = fragmentStart + len(fragment)
        selectionStart = html.index(selection)
        selectionEnd = selectionStart + len(selection)
        self.PutToClipboard(html, fragmentStart, fragmentEnd, selectionStart, selectionEnd, source)


    def PutToClipboard(self, html, fragmentStart, fragmentEnd, selectionStart, selectionEnd, source=\"None\"):
        \"\"\"
        Replace the Clipboard contents with the given html information.
        \"\"\"

        try:
            win32clipboard.OpenClipboard(0)
            win32clipboard.EmptyClipboard()
            src = self.EncodeClipboardSource(html, fragmentStart, fragmentEnd, selectionStart, selectionEnd, source)
            #print src
            win32clipboard.SetClipboardData(self.GetCfHtml(), src)
        finally:
            win32clipboard.CloseClipboard()


    def EncodeClipboardSource(self, html, fragmentStart, fragmentEnd, selectionStart, selectionEnd, source):
        \"\"\"
        Join all our bits of information into a string formatted as per the HTML format specs.
        \"\"\"
                    # How long is the prefix going to be?
        dummyPrefix = self.MARKER_BLOCK_OUTPUT % (0, 0, 0, 0, 0, 0, source)
        lenPrefix = len(dummyPrefix)

        prefix = self.MARKER_BLOCK_OUTPUT % (lenPrefix, len(html)+lenPrefix,
                        fragmentStart+lenPrefix, fragmentEnd+lenPrefix,
                        selectionStart+lenPrefix, selectionEnd+lenPrefix,
                        source)
        return (prefix + html)

if __name__ == '__main__':
    import sys
    data = sys.stdin.read()
    cb = HtmlClipboard()
    cb.PutFragment(data)

"
  "Windows Python Script for copying formatted text")


(defvar ox-clip-w32-cmd
  (expand-file-name "html-clip-w32.py"
		    (file-name-directory (or load-file-name (buffer-file-name))))
  "Absolute path to html-clip-w32.py.")

(unless (and (eq system-type 'windows-nt)
	     (file-exists-p ox-clip-w32-cmd))
  (with-temp-file "html-clip-w32.py"
    (insert ox-clip-w32-py)))

(defun formatted-copy-win32 ()
  "Export region to html and copy to Windows clipboard."
  (interactive)
  (unless (file-exists-p ox-clip-w32-cmd)
    (error "You need to set `ox-clip-w32-cmd' to the absolute path to html-clip-w32.py"))
  (save-window-excursion
    (let* ((buf (org-export-to-buffer 'html "*Formatted Copy*" nil nil t t))
           (html (with-current-buffer buf (buffer-string))))
      (with-current-buffer buf
        (shell-command-on-region
         (point-min)
         (point-max)
         (format  "python %s" ox-clip-w32-cmd)))
      (kill-buffer buf))))


(defun formatted-copy-osx ()
  "Export region to HTML, convert to RTF and copy to Mac clipboard."
  (interactive)
  (save-window-excursion
    (let* ((buf (org-export-to-buffer 'html "*Formatted Copy*" nil nil t t))
	   (html (with-current-buffer buf (buffer-string))))
      (with-current-buffer buf
	(shell-command-on-region
	 (point-min)
	 (point-max)
	 "textutil -stdin -format html -convert rtf -stdout | pbcopy"))
      (kill-buffer buf))))


(defun formatted-copy-linux ()
  "Export region to HTML and copy to Linux clipboard."
  (interactive)
  ;; from https://github.com/abo-abo/oremacs/blob/6c86696c0a1f66bf690e1a934683f85f04c6f34d/auto.el#L386
  (org-export-to-file 'html "/tmp/org.html" nil nil t t)
  (apply
   'start-process "xclip" "*xclip*"
   (split-string
    "xclip -verbose -i /tmp/org.html -t text/html -selection clipboard" " ")))


;;;###autoload
(defun formatted-copy ()
  "Export the selected region to HTML and copy it to the clipboard.
This just figures out your platform and runs the platform
dependent commands above."
  (interactive)
  (cond
   ((eq system-type 'windows-nt)
    (formatted-copy-win32))
   ((eq system-type 'darwin)
    formatted-copy-osx)
   ((eq system-type 'gnu/linux)
    (formatted-copy-linux))))






(provide 'ox-clip)

;;; ox-clip.el ends here
