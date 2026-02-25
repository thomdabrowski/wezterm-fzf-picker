# WezTerm Workspace Picker

Fuzzy project picker for WezTerm workspaces using fzf.

Features:
- `Leader + g` opens fzf picker to switch between project workspaces
- `Leader + b` toggles back to previous workspace
- `Leader + [/]` cycles through workspaces
- Active workspaces are highlighted in green
- `alt-v` opens nvim in the selected workspace
- Workspace name + clock in the status bar

## Requirements

- [WezTerm](https://wezfurlong.org/wezterm/)
- [fzf](https://github.com/junegunn/fzf)
- [jq](https://jqlang.github.io/jq/)
- A Nerd Font (e.g. JetBrainsMono Nerd Font)

## Installation

1. Copy scripts and make them executable:

```bash
cp scripts/* ~/.config/scripts/
chmod +x ~/.config/scripts/project-selector ~/.config/scripts/project-cache-refresh
```

2. Add scripts to your PATH (in `.zshrc` or `.bashrc`):

```bash
export PATH="$HOME/.config/scripts:$PATH"
```

3. Copy WezTerm config:

```bash
cp wezterm/* ~/.config/wezterm/
```

4. Edit `scripts/project-cache-refresh` to point at your project directories.

5. Build the initial cache:

```bash
project-cache-refresh
```

## Usage

- Press `Leader + g` (default leader is `Ctrl-b`) to open the workspace picker
- Type to filter, `enter` to switch, `alt-v` to open nvim in the workspace
- Press `Leader + b` to jump back to the previous workspace

## Customization

- **Leader key**: Change `config.leader` in `wezterm.lua`
- **Project dirs**: Edit the paths in `scripts/project-cache-refresh`
- **Auto-refresh**: Set up a cron/launchd job to run `project-cache-refresh` periodically
