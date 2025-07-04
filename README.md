# Claude Code Authentication Switcher

A macOS utility that allows switching between Claude Code personal plan authentication and API billing authentication using macOS Keychain. If you want to quickly switch from Pro/Max to API billing when you run out, you found the right tool.

This tool requires macOS.

## Installation

[Download ccas.sh](https://raw.githubusercontent.com/khromov/claude-code-auth-switcher/refs/heads/main/ccas.sh) from this repository and save it to any folder.

To make `ccas` available globally so you can run `ccas personal` from anywhere:

1. Make the script executable:

   ```bash
   chmod +x ccas.sh
   ```

2. Create a symlink in `/usr/local/bin`:

   ```bash
   sudo ln -sf "$(pwd)/ccas.sh" /usr/local/bin/ccas
   ```

3. Start a new bash terminal, then follow the setup process by running:

   ```bash
   ccas setup
   ```

4. Verify it works:
   ```bash
   ccas personal # switch to personal claude.ai token
   ccas api # switch to Anthropic pay-as-you-go API
   ```

## Update

To update to the latest version:

1. Follow the uninstall instructions below
2. Download the latest `ccas.sh` from this repository
3. Follow the installation instructions above

**To uninstall:**

```bash
sudo rm /usr/local/bin/ccas
```
