# ssh_pass2key

This project provides a small Bash helper `pass2key.sh` to install your local SSH public key onto remote hosts' `authorized_keys`, converting password-based access to key-based access.

Usage example:

```bash
./pass2key.sh --hosts hosts.txt --user ubuntu --dry-run
```

Password automation (optional):

- You can enable `sshpass` support with `--sshpass` and provide a password interactively using `--ask-password` (the script will prompt without echoing the password):

```bash
./pass2key.sh --hosts hosts.txt --user ubuntu --sshpass --ask-password
```

Security warning: using `sshpass` exposes credentials to the process environment and should only be used in controlled scenarios. Prefer interactive SSH key installation or a secure secret store.

Run directly from the web (no clone required):

```bash
curl -sSL https://raw.githubusercontent.com/Ivanbeethoven/ssh_pass2key/master/pass2key.sh | bash -s -- --interactive
```

Be careful: piping scripts from the internet to `bash` executes code on your machine. Inspect the script before running in sensitive environments.

hosts.txt format:

- Each line is a host name or host:port
- Lines starting with `#` are comments

Security notes:

- The script prefers `ssh-copy-id` when available.
- It will generate an `ed25519` keypair at `~/.ssh/id_ed25519` if no key exists.
- It will backup existing keys before overwriting.

Do not store plain passwords in the hosts file or in this repository.
