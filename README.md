# ssh_pass2key

This project provides a small Bash helper `pass2key.sh` to install your local SSH public key onto remote hosts' `authorized_keys`, converting password-based access to key-based access.

Usage example:

```bash
./pass2key.sh --hosts hosts.txt --user ubuntu --dry-run
```

hosts.txt format:

- Each line is a host name or host:port
- Lines starting with `#` are comments

Security notes:

- The script prefers `ssh-copy-id` when available.
- It will generate an `ed25519` keypair at `~/.ssh/id_ed25519` if no key exists.
- It will backup existing keys before overwriting.

Do not store plain passwords in the hosts file or in this repository.
