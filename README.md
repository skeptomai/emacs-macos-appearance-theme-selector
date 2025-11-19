# appearance-theme-selector.el

A smart Emacs package for semi-automatic theme selection based on macOS system appearance changes. Instead of forcing you into rigid light/dark theme pairs, this package lets you choose from your preferred themes when the system appearance changes.

## Features

- **Smart Theme Selection**: Choose from your preferred themes when macOS switches between light and dark mode
- **Persistent Preferences**: Remembers your selections across Emacs sessions
- **Semi-Automatic**: Prompts for selection on first use, then applies your saved preference
- **Native Integration**: Uses Emacs 29.1+ built-in macOS appearance change hooks
- **Flexible Configuration**: Separate theme lists for light and dark modes
- **Manual Override**: Commands to change preferences or manually select themes

## Requirements

- Emacs 29.1 or later
- macOS with system appearance support
- Your preferred themes installed (e.g., `modus-themes`, `doom-themes`, etc.)

## Installation

### Method 1: Manual Installation

1. Download `appearance-theme-selector.el` to your Emacs configuration directory
2. Add to your `init.el`:

```elisp
(add-to-list 'load-path "/path/to/appearance-theme-selector")
(require 'appearance-theme-selector)
```

### Method 2: use-package with straight.el

```elisp
(use-package appearance-theme-selector
  :straight (:host github :repo "skeptomai/emacs-macos-appearance-theme-selector")
  :config
  (setq appearance-theme-selector-light-themes
        '(modus-operandi ef-summer leuven))
  (setq appearance-theme-selector-dark-themes
        '(modus-vivendi ef-winter doom-one))
  (appearance-theme-selector-mode 1))
```

### Method 3: use-package with manual download

```elisp
(use-package appearance-theme-selector
  :load-path "/path/to/appearance-theme-selector"
  :config
  (setq appearance-theme-selector-light-themes
        '(modus-operandi ef-summer leuven))
  (setq appearance-theme-selector-dark-themes
        '(modus-vivendi ef-winter doom-one))
  (appearance-theme-selector-mode 1))
```

## Configuration

### Basic Setup

```elisp
;; Configure your preferred themes
(setq appearance-theme-selector-light-themes
      '(modus-operandi ef-summer leuven dichromacy))

(setq appearance-theme-selector-dark-themes
      '(modus-vivendi ef-winter doom-one tango-dark))

;; Enable the mode
(appearance-theme-selector-mode 1)
```

### Advanced Configuration

```elisp
;; Always prompt when appearance changes (default: t)
(setq appearance-theme-selector-prompt-on-change t)

;; Custom save file location (default: ~/.emacs.d/appearance-theme-preferences.el)
(setq appearance-theme-selector-save-file
      (expand-file-name "my-theme-prefs.el" user-emacs-directory))
```

## Usage

### First Time Setup

1. Enable `appearance-theme-selector-mode`
2. Change your macOS system appearance (System Preferences → General → Appearance)
3. Choose your preferred theme from the prompt
4. Your selection is saved and will be used automatically in future appearance changes

### How It Works

1. **Initial Prompt**: When macOS appearance changes for the first time, you'll be prompted to select from your configured theme list
2. **Automatic Application**: Your selection is saved and automatically applied on subsequent appearance changes
3. **Persistent Storage**: Preferences are saved to `~/.emacs.d/appearance-theme-preferences.el`

## Commands

| Command | Description |
|---------|-------------|
| `M-x appearance-theme-selector-choose-theme` | Manually select a theme for current appearance mode |
| `M-x appearance-theme-selector-reset-preferences` | Clear saved preferences (will prompt again on next change) |
| `M-x appearance-theme-selector-show-preferences` | Display current theme preferences |
| `M-x appearance-theme-selector-apply-current` | Apply appropriate theme for current system appearance |
| `M-x appearance-theme-selector-mode` | Toggle the minor mode on/off |

## Example Workflow

```elisp
;; In your init.el
(setq appearance-theme-selector-light-themes
      '(modus-operandi ef-summer))
(setq appearance-theme-selector-dark-themes
      '(modus-vivendi doom-one))
(appearance-theme-selector-mode 1)
```

1. Switch macOS to dark mode → Prompted to choose between `modus-vivendi` and `doom-one`
2. Select `modus-vivendi` → Applied immediately and saved as preference
3. Switch macOS to light mode → Prompted to choose between `modus-operandi` and `ef-summer`
4. Select `ef-summer` → Applied and saved
5. Future appearance changes automatically use your saved preferences

## Troubleshooting

### Theme Not Loading
- Ensure the theme is installed and available
- Check that theme names in your configuration match exactly (case-sensitive)
- Verify themes work with `M-x load-theme`

### No Appearance Change Detection
- Requires Emacs 29.1+ on macOS
- Check that `ns-system-appearance-change-functions` exists:
  ```elisp
  (boundp 'ns-system-appearance-change-functions)
  ```

### Preferences Not Persisting
- Check file permissions for your Emacs directory
- Verify `appearance-theme-selector-save-file` path is writable
- Check for errors in the `*Messages*` buffer

### Reset Everything
```elisp
(appearance-theme-selector-reset-preferences)
(appearance-theme-selector-mode -1)
(appearance-theme-selector-mode 1)
```

## Contributing

Issues and pull requests are welcome! Please ensure:

- Code follows Emacs Lisp conventions
- Include docstrings for public functions
- Test on Emacs 29.1+ with macOS
- Maintain backward compatibility

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Related Packages

- [modus-themes](https://github.com/protesilaos/modus-themes) - Excellent built-in accessible themes
- [doom-themes](https://github.com/doomemacs/themes) - Popular theme collection
- [ef-themes](https://github.com/protesilaos/ef-themes) - Colorful, legible themes