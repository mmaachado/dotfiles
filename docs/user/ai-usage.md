# AI usage

A ring beside the tray shows how much of your AI plans you've used, from
[ai-usagebar](https://github.com/akitaonrails/ai-usagebar): Claude, Codex,
GitHub Copilot and many more.

```sh
./install.py packages -g ai      # builds ai-usagebar into ~/.local (needs rust)
```

- The ring shows your **most used limit**, in the accent colour, orange from
  70% and red from 90%. Hover it to see which limit it is.
- **Click** it for every provider: its plan, and each limit (for Claude, the
  5-hour session and the weekly limit) with a usage bar and when it resets.
- It refreshes every 5 minutes, and whenever you open it.

## Providers

ai-usagebar finds most logins by itself: Claude Code's
(`~/.claude/.credentials.json`), Codex's (`~/.codex/auth.json`), and GitHub
Copilot's through `gh`. Others need an API key: **Configure…** in the popup
opens `~/.config/ai-usagebar/config.toml` (see ai-usagebar's
[configuration guide](https://github.com/akitaonrails/ai-usagebar)).
Providers that aren't set up are left out.

Turn the ring off in Settings → Tray.
