;;; appearance-theme-selector.el --- Select themes based on system appearance -*- lexical-binding: t; -*-

;; Copyright (C) 2024 Christopher Brown

;; Author: Christopher Brown
;; Version: 1.0.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: faces, themes
;; URL: https://github.com/skeptomai/emacs-macos-appearance-theme-selector

;;; Commentary:

;; This package provides a semi-manual theme selection workflow that
;; responds to macOS system appearance changes (light/dark mode).
;; Rather than automatically switching to a fixed theme pair, it allows
;; you to select from a list of preferred themes for each appearance mode.
;;
;; Features:
;; - Maintains separate lists of light and dark themes
;; - Prompts for theme selection on first appearance change
;; - Remembers your selections across Emacs sessions
;; - Provides commands to manually change theme preferences
;; - Integrates with Emacs 29+ native appearance change hooks
;;
;; Usage:
;;
;;   (require 'appearance-theme-selector)
;;   (setq appearance-theme-selector-light-themes
;;         '(modus-operandi ef-summer leuven))
;;   (setq appearance-theme-selector-dark-themes
;;         '(modus-vivendi ef-winter doom-one))
;;   (appearance-theme-selector-mode 1)
;;
;; Commands:
;;
;; M-x appearance-theme-selector-choose-theme
;;   Manually select a theme for the current appearance mode
;;
;; M-x appearance-theme-selector-reset-preferences
;;   Clear saved theme preferences and re-prompt on next change

;;; Code:

(require 'custom)

;;; Customization

(defgroup appearance-theme-selector nil
  "Select themes based on system appearance."
  :group 'faces
  :prefix "appearance-theme-selector-")

(defcustom appearance-theme-selector-light-themes
  '(modus-operandi leuven dichromacy)
  "List of themes to choose from in light mode.
These should be theme symbols that can be passed to `load-theme'."
  :type '(repeat symbol)
  :group 'appearance-theme-selector)

(defcustom appearance-theme-selector-dark-themes
  '(modus-vivendi wombat tango-dark)
  "List of themes to choose from in dark mode.
These should be theme symbols that can be passed to `load-theme'."
  :type '(repeat symbol)
  :group 'appearance-theme-selector)

(defcustom appearance-theme-selector-prompt-on-change t
  "Whether to prompt for theme selection when appearance changes.
If nil, will only prompt the first time or when explicitly commanded."
  :type 'boolean
  :group 'appearance-theme-selector)

(defcustom appearance-theme-selector-save-file
  (locate-user-emacs-file "appearance-theme-preferences.el")
  "File where theme preferences are persisted across sessions."
  :type 'file
  :group 'appearance-theme-selector)

;;; Internal Variables

(defvar appearance-theme-selector--preferences nil
  "Alist mapping appearance modes to selected themes.
Format: ((light . theme-symbol) (dark . theme-symbol))")

(defvar appearance-theme-selector--last-appearance nil
  "The last appearance mode we responded to.")

;;; Persistence

(defun appearance-theme-selector--load-preferences ()
  "Load saved theme preferences from disk."
  (when (file-exists-p appearance-theme-selector-save-file)
    (condition-case err
        (with-temp-buffer
          (insert-file-contents appearance-theme-selector-save-file)
          (setq appearance-theme-selector--preferences
                (read (current-buffer))))
      (error
       (message "Failed to load appearance-theme-selector preferences: %s" err)
       (setq appearance-theme-selector--preferences nil)))))

(defun appearance-theme-selector--save-preferences ()
  "Save current theme preferences to disk."
  (condition-case err
      (with-temp-file appearance-theme-selector-save-file
        (prin1 appearance-theme-selector--preferences (current-buffer)))
    (error
     (message "Failed to save appearance-theme-selector preferences: %s" err))))

;;; Core Functions

(defun appearance-theme-selector--get-themes-for-appearance (appearance)
  "Return the list of available themes for APPEARANCE mode."
  (pcase appearance
    ('light appearance-theme-selector-light-themes)
    ('dark appearance-theme-selector-dark-themes)
    (_ (error "Unknown appearance mode: %s" appearance))))

(defun appearance-theme-selector--get-saved-theme (appearance)
  "Get the saved theme preference for APPEARANCE mode, if any."
  (alist-get appearance appearance-theme-selector--preferences))

(defun appearance-theme-selector--save-theme (appearance theme)
  "Save THEME as the preference for APPEARANCE mode."
  (setf (alist-get appearance appearance-theme-selector--preferences)
        theme)
  (appearance-theme-selector--save-preferences))

(defun appearance-theme-selector--select-theme (appearance &optional force-prompt)
  "Select and return a theme for APPEARANCE mode.
If FORCE-PROMPT is non-nil, always prompt even if a preference exists.
Otherwise, return saved preference or prompt if none exists."
  (let* ((saved-theme (appearance-theme-selector--get-saved-theme appearance))
         (available-themes (appearance-theme-selector--get-themes-for-appearance appearance))
         (should-prompt (or force-prompt
                           (not saved-theme)
                           appearance-theme-selector-prompt-on-change)))
    (if (and saved-theme (not force-prompt))
        saved-theme
      (let ((selected (intern
                      (completing-read
                       (format "Select %s theme: " appearance)
                       (mapcar #'symbol-name available-themes)
                       nil
                       t
                       (when saved-theme (symbol-name saved-theme))))))
        (appearance-theme-selector--save-theme appearance selected)
        selected))))

(defun appearance-theme-selector--apply-theme (theme)
  "Apply THEME, disabling all currently active themes first."
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme theme t)
  (message "Loaded theme: %s" theme))

(defun appearance-theme-selector--handle-appearance-change (appearance)
  "Handle system appearance change to APPEARANCE mode.
This is the main hook function that responds to system changes."
  ;; Only act if appearance actually changed
  (unless (eq appearance appearance-theme-selector--last-appearance)
    (setq appearance-theme-selector--last-appearance appearance)
    (let ((theme (appearance-theme-selector--select-theme appearance)))
      (appearance-theme-selector--apply-theme theme))))

(defun appearance-theme-selector--current-appearance ()
  "Determine current system appearance mode.
Returns 'light or 'dark based on frame background mode."
  (if (eq (frame-parameter nil 'background-mode) 'dark)
      'dark
    'light))

;;; Interactive Commands

;;;###autoload
(defun appearance-theme-selector-choose-theme (&optional appearance)
  "Manually select a theme for APPEARANCE mode.
If APPEARANCE is nil, use current system appearance.
This command always prompts for selection and saves the preference."
  (interactive)
  (let* ((mode (or appearance (appearance-theme-selector--current-appearance)))
         (theme (appearance-theme-selector--select-theme mode t)))
    (appearance-theme-selector--apply-theme theme)))

;;;###autoload
(defun appearance-theme-selector-reset-preferences ()
  "Clear all saved theme preferences.
You will be prompted to select themes on the next appearance change."
  (interactive)
  (when (yes-or-no-p "Clear all saved theme preferences? ")
    (setq appearance-theme-selector--preferences nil)
    (appearance-theme-selector--save-preferences)
    (message "Theme preferences cleared")))

;;;###autoload
(defun appearance-theme-selector-show-preferences ()
  "Display current theme preferences."
  (interactive)
  (let ((light-theme (appearance-theme-selector--get-saved-theme 'light))
        (dark-theme (appearance-theme-selector--get-saved-theme 'dark)))
    (message "Light theme: %s | Dark theme: %s"
             (or light-theme "not set")
             (or dark-theme "not set"))))

;;;###autoload
(defun appearance-theme-selector-apply-current ()
  "Apply the appropriate theme for current system appearance.
Useful for initial setup or manual synchronization."
  (interactive)
  (let ((appearance (appearance-theme-selector--current-appearance)))
    (appearance-theme-selector--handle-appearance-change appearance)))

;;; Minor Mode

;;;###autoload
(define-minor-mode appearance-theme-selector-mode
  "Toggle automatic theme selection based on system appearance.

When enabled, this mode monitors system appearance changes (light/dark mode)
and prompts you to select an appropriate theme from your configured lists.
Your selections are saved and reused across Emacs sessions.

This mode requires Emacs 29.1 or later with macOS appearance change support."
  :global t
  :group 'appearance-theme-selector
  :lighter " ATS"
  (if appearance-theme-selector-mode
      (progn
        ;; Enable mode
        (unless (boundp 'ns-system-appearance-change-functions)
          (error "This package requires Emacs 29.1+ with macOS appearance support"))
        (appearance-theme-selector--load-preferences)
        (add-hook 'ns-system-appearance-change-functions
                  #'appearance-theme-selector--handle-appearance-change)
        ;; Apply theme for current appearance
        (appearance-theme-selector-apply-current)
        (message "Appearance theme selector enabled"))
    ;; Disable mode
    (remove-hook 'ns-system-appearance-change-functions
                 #'appearance-theme-selector--handle-appearance-change)
    (message "Appearance theme selector disabled")))

(provide 'appearance-theme-selector)

;;; appearance-theme-selector.el ends here
