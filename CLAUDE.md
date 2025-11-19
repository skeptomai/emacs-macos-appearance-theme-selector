# Appearance Theme Selector - Emacs Package

This is an Emacs Lisp package that automatically switches themes when macOS changes between light and dark appearance modes.

## Package Overview

- **Main file**: `appearance-theme-selector.el` - Complete package implementation
- **Target**: Emacs 29.1+ on macOS with native appearance change support
- **Purpose**: Semi-automatic theme selection based on system appearance

## Key Features

- Maintains separate lists of light/dark theme preferences
- Prompts for theme selection on first appearance change
- Persists user selections across Emacs sessions
- Integrates with Emacs 29+ native `ns-system-appearance-change-functions`

## Development Guidelines

When working on this package:

1. **Maintain compatibility** with Emacs 29.1+ package standards
2. **Follow elisp conventions** - proper docstrings, autoload cookies, custom groups
3. **Preserve the semi-manual approach** - don't make it fully automatic
4. **Keep error handling robust** - graceful fallbacks for file I/O and theme loading
5. **Test on macOS** - requires `ns-system-appearance-change-functions` support

## Package Structure

- Customization variables for theme lists and behavior
- Persistence layer for saving/loading preferences
- Core selection and application logic
- Interactive commands for manual control
- Minor mode for enabling/disabling functionality

## Testing

Test with various scenarios:
- Initial setup (no saved preferences)
- Appearance changes with existing preferences
- Theme loading failures
- Invalid preference files
- Manual command invocation