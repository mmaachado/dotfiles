# Troubleshooting

## Restart the shell

```sh
kshell restart
pgrep -a -x qs      # should list exactly one `qs -c kshell`
```

Use `kshell restart`, not `qs kill` and a manual relaunch: that can leave
several copies running, with bars stacked on top of each other. `kshell stop`
also catches a copy Quickshell's crash handler restarted.

## Read the log

```sh
just log            # in the repo: KShell's latest warnings and errors
```

## Check the install

```sh
./install.py check
```

It reports missing packages, fonts and links, the login shell, and what
`sans-serif` and `monospace` resolve to.

## Screenshots come out blank

A monitor in power-saving (DPMS) mode isn't repainted. Wake it first:
`kscreen-doctor --dpms on`.

## Back to plain Plasma

```sh
./install.py kshell disable
```
