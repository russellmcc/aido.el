;;; aido.el --- Uses AI to do something based on a prompt -*- lexical-binding: t; -*-

;; Version: 0.1
;; Copyright (c) 2023 James R. McClellan
;; Package-Requires: ((gptel "0.10"))

;; SPDX-License-Identifier: GPL-3.0-or-later

(defvar-local aido--system-message
  "You are a large language model built into emacs.  Your purpose is to translate user commands into emacs lisp code to perform the action described by the user.  The code must actually work and perform the action the user requested.  There must only be a single code block.  The format of your response must be an org-mode document, with a single code block containing the emacs-lisp code, and not other code blocks.  Any emacs-lisp code blocks you create will be immediately executed.  For example, if a user says:

#+BEGIN_QUOTE
start playing towers of hanoi
#+END_QUOTE

You might respond

#+BEGIN_SRC emacs-lisp
(hanoi)
#+END_SRC

As another example,

#+BEGIN_QUOTE
play snake
#+END_QUOTE

You must respond with:

#+BEGIN_SRC emacs-lisp
(snake)
#+END_SRC

Nested code blocks, that is putting the ~#+BEGIN_SRC emacs-lisp~ line inside a code block is ILLEGAL and will not be tolerated under any circumstances whatsoever.  Never do this.

The assistant will NEVER produce a nested code block.

To summarize your rules:

 - Include only one emacs-lisp code block containing code to perform the users request.
 - Format your response as an org-mode document
 - NEVER nest code blocks, not matter what.
 - make sure the code block is tagged with ~emacs-lisp~
")

(defvar-local aido--reminder
  "I'll try to help, but no matter what, I won't produce a nested code block. I would never do that. Instead I'll produce a single ~emacs-lisp~ code block.")

(defun aido--make-prompt (query)
  "Makes the prompts"
  (list (list :role "system"
              :content aido--system-message)
        (list :role "user"
              :content query)
        (list :role "assistant"
              :content aido--reminder)))

(defun aido--execute-babel-buffer ()
  "Execute all source code blocks in a buffer.
Call `org-babel-execute-src-block' interactively on every source block in
the current buffer."
  (interactive)
  (org-babel-eval-wipe-error-buffer)
  (org-save-outline-visibility t
    (goto-char (point-min))
    (while (re-search-forward
		    "\\(call\\|src\\)_\\|^[ \t]*#\\+\\(BEGIN_SRC\\|CALL:\\)" nil t)
      (goto-char (match-beginning 0))
      (let ((end (org-element-property :end (org-element-context))))
        (if end
          (progn
            (org-babel-execute-src-block)
            (goto-char end))
          (goto-char (+ 1 (match-beginning 0))))))))


;; Test case:
;; (aido "I have two windows open pointing to two different buffers.  Can you swap which buffers the windows are showing?")
;; (aido "Play snake using built-in emacs command")

(defvar aido--history nil)

;;;###autoload
(defun aido (query &optional display-aido-buffer)
  (interactive (list (completing-read "Do with AI: " aido--history nil nil nil 'aido--history) current-prefix-arg))
  "Use AI to do something in emacs"
  (let* ((prompt (aido--make-prompt query))
         (aido-buf-name "*aido*")
         (old-buf (get-buffer aido-buf-name))
         (aido-buf (progn
                     (when old-buf
                       (kill-buffer old-buf))
                     (generate-new-buffer aido-buf-name))))
    (with-current-buffer aido-buf
      (org-mode)
      (when display-aido-buffer (display-buffer aido-buf))
      (gptel--url-get-response
       (list :prompt prompt
             :gptel-buffer aido-buf
             :insert-marker (point-min))
       (lambda (response info)
         (gptel--insert-response response info)
         (with-current-buffer aido-buf
           (call-interactively #'aido--execute-babel-buffer)))))))

(provide 'aido)
;;; aido.el ends here