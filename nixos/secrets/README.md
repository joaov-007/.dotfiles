# Secrets

Encrypted with [agenix-rekey](https://github.com/oddlama/agenix-rekey).

## Setup

1. Generate your host SSH pubkey (if not already done):
   ```bash
   ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key
   ```

2. Set `age.rekey.hostPubkey` in your host's `configuration.nix`:
   ```nix
   age.rekey.hostPubkey = "ssh-ed25519 AAAA...";
   ```

3. Create a new secret:
   ```bash
   agenix edit secrets/my-secret.age
   ```

4. Rekey all secrets:
   ```bash
   agenix-rekey rekey
   ```

5. Deploy:
   ```bash
   sudo nixos-rebuild switch --flake .#bacon
   ```

## Password hashes

Generate a hash:
```bash
mkpasswd -m SHA-512
```

Then encrypt it:
```bash
mkpasswd -m SHA-512 | agenix edit secrets/joaov-pw-hash.age
```
