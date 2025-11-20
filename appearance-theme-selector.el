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
;; - Non-blocking warnings when themes need to be configured
;; - Remembers your selections across Emacs sessions
;; - Provides commands to manually change theme preferences
;; - Integrates with Emacs 29+ native appearance change hooks
;; - Prevents hanging during system appearance changes
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
;; M-x appearance-theme-selector-cycle-theme
;;   Cycle through recently used themes for current appearance
;;
;; M-x appearance-theme-selector-add-theme
;;   Add a theme to the configured list for current or specified appearance
;;
;; M-x appearance-theme-selector-setup-themes
;;   Set up both light and dark theme preferences at once
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
  "Alist mapping appearance modes to recently used themes.
Format: ((light . (theme1 theme2 theme3)) (dark . (theme1 theme2 theme3)))
Themes are stored in most-recently-used order.")

(defvar appearance-theme-selector--last-appearance nil
  "The last appearance mode we responded to.")

;;; Persistence

(defun appearance-theme-selector--load-preferences ()
  "Load saved theme preferences from disk.
Automatically migrates old format to new recently-used format."
  (when (file-exists-p appearance-theme-selector-save-file)
    (condition-case err
        (with-temp-buffer
          (insert-file-contents appearance-theme-selector-save-file)
          (let ((loaded-prefs (read (current-buffer))))
            ;; Check if we need to migrate from old format
            (setq appearance-theme-selector--preferences
                  (appearance-theme-selector--migrate-preferences loaded-prefs))))
      (error
       (message "Failed to load appearance-theme-selector preferences: %s" err)
       (setq appearance-theme-selector--preferences nil)))))

(defun appearance-theme-selector--migrate-preferences (prefs)
  "Migrate PREFS from old format to new recently-used format.
Old format: ((light . theme-symbol) (dark . theme-symbol))
New format: ((light . (theme-list)) (dark . (theme-list)))"
  (mapcar (lambda (entry)
            (let ((appearance (car entry))
                  (theme-or-list (cdr entry)))
              (if (listp theme-or-list)
                  ;; Already new format
                  entry
                ;; Old format - convert single theme to list
                (cons appearance (list theme-or-list)))))
          prefs))

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
  "Get the most recently used theme for APPEARANCE mode, if any."
  (car (alist-get appearance appearance-theme-selector--preferences)))

(defun appearance-theme-selector--save-theme (appearance theme)
  "Save THEME as the most recently used theme for APPEARANCE mode.
Maintains a list of recently used themes, with the new theme moved to the front."
  (let ((current-themes (alist-get appearance appearance-theme-selector--preferences)))
    ;; Remove theme if it already exists, then add to front
    (setq current-themes (cons theme (remove theme current-themes)))
    ;; Keep only the 5 most recent themes
    (setq current-themes (seq-take current-themes 5))
    ;; Update the preferences
    (setf (alist-get appearance appearance-theme-selector--preferences)
          current-themes))
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
This is the main hook function that responds to macOS system changes.
Uses non-blocking warnings instead of prompts to avoid hanging during system hooks."
  ;; Only act if appearance actually changed to avoid redundant processing
  (unless (eq appearance appearance-theme-selector--last-appearance)
    (setq appearance-theme-selector--last-appearance appearance)
    (let ((saved-theme (appearance-theme-selector--get-saved-theme appearance))
          (available-themes (appearance-theme-selector--get-themes-for-appearance appearance)))
      (cond
       ;; No themes configured for this appearance mode
       ((null available-themes)
        (display-warning 'appearance-theme-selector
                        (format "No %s themes configured. Set appearance-theme-selector-%s-themes."
                                appearance appearance)
                        :warning))
       ;; Have saved preference - apply it immediately
       (saved-theme
        (appearance-theme-selector--apply-theme saved-theme))
       ;; No saved preference - warn user to select manually (avoids blocking prompts)
       (t
        (display-warning 'appearance-theme-selector
                        (format "No saved %s theme preference. Use M-x appearance-theme-selector-choose-theme to select one."
                                appearance)
                        :warning))))))

(defun appearance-theme-selector--current-appearance ()
  "Determine current system appearance mode.
Returns 'light or 'dark based on macOS system appearance.
Uses ns-system-appearance for accurate macOS detection, with fallback to frame background mode."
  (if (and (boundp 'ns-system-appearance)
           ns-system-appearance)
      ;; Use macOS system appearance when available (Emacs 29.1+)
      (if (eq ns-system-appearance 'dark)
          'dark
        'light)
    ;; Fallback to frame background mode if ns-system-appearance unavailable
    (if (eq (frame-parameter nil 'background-mode) 'dark)
        'dark
      'light)))

;;; Interactive Commands

;;;###autoload
(defun appearance-theme-selector-choose-theme (&optional appearance)
  "Manually select a theme for APPEARANCE mode.
If APPEARANCE is nil, use current system appearance.
This command always prompts for selection and saves the preference.
Only applies the theme if it matches the current system appearance to prevent
applying light themes in dark mode and vice versa."
  (interactive)
  (let* ((mode (or appearance (appearance-theme-selector--current-appearance)))
         (current-appearance (appearance-theme-selector--current-appearance))
         (theme (appearance-theme-selector--select-theme mode t)))
    (if (eq mode current-appearance)
        ;; Theme matches current appearance - apply it
        (appearance-theme-selector--apply-theme theme)
      ;; Theme doesn't match current appearance - save but don't apply
      (message "Theme %s saved for %s mode (not applied since system is currently %s)"
               theme mode current-appearance))))

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
  (let ((light-themes (alist-get 'light appearance-theme-selector--preferences))
        (dark-themes (alist-get 'dark appearance-theme-selector--preferences)))
    (message "Recent light themes: %s | Recent dark themes: %s"
             (if light-themes
                 (mapconcat #'symbol-name light-themes ", ")
               "none")
             (if dark-themes
                 (mapconcat #'symbol-name dark-themes ", ")
               "none"))))

;;;###autoload
(defun appearance-theme-selector-setup-themes ()
  "Set up theme preferences for both light and dark modes.
This is a convenience command for initial configuration.
Prompts for both themes but only applies the one matching current system appearance."
  (interactive)
  ;; Set up both themes without applying either during selection
  (message "Setting up light theme preference...")
  (appearance-theme-selector--select-theme 'light t)

  (message "Setting up dark theme preference...")
  (appearance-theme-selector--select-theme 'dark t)

  ;; Apply the correct theme for current system state
  (let* ((current-appearance (appearance-theme-selector--current-appearance))
         (current-theme (appearance-theme-selector--get-saved-theme current-appearance)))
    (if current-theme
        (progn
          (appearance-theme-selector--apply-theme current-theme)
          (message "Setup complete. Applied %s theme for current %s mode."
                   current-theme current-appearance))
      (error "Failed to get theme for current %s appearance" current-appearance))))

;;;###autoload
(defun appearance-theme-selector-apply-current ()
  "Apply the appropriate theme for current system appearance.
Useful for initial setup or manual synchronization."
  (interactive)
  (let ((appearance (appearance-theme-selector--current-appearance)))
    (appearance-theme-selector--handle-appearance-change appearance)))

;;;###autoload
(defun appearance-theme-selector-add-theme (theme &optional appearance)
  "Add THEME to the configured list for APPEARANCE mode.
If APPEARANCE is nil, add to the list for current system appearance.
This makes the theme available for selection without immediately applying it."
  (interactive
   (list (intern (completing-read "Theme to add: "
                                  (mapcar #'symbol-name (custom-available-themes))
                                  nil t))
         (when current-prefix-arg
           (intern (completing-read "Appearance mode: " '("light" "dark") nil t)))))
  (let ((mode (or appearance (appearance-theme-selector--current-appearance))))
    (cond
     ((eq mode 'light)
      (unless (memq theme appearance-theme-selector-light-themes)
        (setq appearance-theme-selector-light-themes
              (append appearance-theme-selector-light-themes (list theme)))
        (message "Added %s to light themes" theme)))
     ((eq mode 'dark)
      (unless (memq theme appearance-theme-selector-dark-themes)
        (setq appearance-theme-selector-dark-themes
              (append appearance-theme-selector-dark-themes (list theme)))
        (message "Added %s to dark themes" theme)))
     (t (error "Unknown appearance mode: %s" mode)))))

;;;###autoload
(defun appearance-theme-selector-cycle-theme (&optional backward)
  "Cycle through recently used themes for current appearance mode.
If BACKWARD is non-nil, cycle in reverse order.
If no recently used themes exist, prompt to select from configured themes."
  (interactive "P")
  (let* ((current-appearance (appearance-theme-selector--current-appearance))
         (recent-themes (alist-get current-appearance appearance-theme-selector--preferences))
         (available-themes (appearance-theme-selector--get-themes-for-appearance current-appearance)))
    (cond
     ;; No recent themes - prompt to select one
     ((null recent-themes)
      (let ((theme (appearance-theme-selector--select-theme current-appearance t)))
        (appearance-theme-selector--apply-theme theme)))
     ;; Only one recent theme - no cycling possible
     ((= (length recent-themes) 1)
      (message "Only one recent %s theme: %s" current-appearance (car recent-themes)))
     ;; Multiple recent themes - cycle through them
     (t
      (let* ((current-theme (car recent-themes))
             (next-theme (if backward
                            (car (last recent-themes))
                          (cadr recent-themes))))
        ;; Move the selected theme to front of recent list
        (appearance-theme-selector--save-theme current-appearance next-theme)
        (appearance-theme-selector--apply-theme next-theme)
        (message "Switched to %s theme: %s (%d/%d)"
                 current-appearance next-theme 1 (length recent-themes)))))))

;;;###autoload
(defun appearance-theme-selector-list-recent-themes (&optional appearance)
  "Show recently used themes for APPEARANCE mode.
If APPEARANCE is nil, show for current system appearance."
  (interactive)
  (let* ((mode (or appearance (appearance-theme-selector--current-appearance)))
         (recent-themes (alist-get mode appearance-theme-selector--preferences)))
    (if recent-themes
        (message "Recent %s themes: %s" mode
                 (mapconcat #'symbol-name recent-themes ", "))
      (message "No recent %s themes" mode))))

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
