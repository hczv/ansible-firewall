# Ansible Squid Role

Install and configure Squid with optional user authentication, per-user domain whitelisting, and optional HTTPS inspection (SSL bump).

This role supports both username/password authentication and IP-based allowances concurrently — you do not need to switch modes.

## Requirements

Ansible 2.9+. Role installs `squid` and `apache2-utils` when `squid_auth_users` is set.

## Important files produced by the role

- `{{ squid_conf_path }}` (default: `/etc/squid/squid.conf`) — rendered from the `squid.conf.j2` template
- `/etc/squid/passwd` — NCSA htpasswd file created when `squid_users` (or legacy `squid_auth_users`) is provided

## Key variables (defaults are shown in the role `defaults/main.yml`)

- `squid_port` (3128): Proxy listen port
- `squid_cache_dir` (/var/spool/squid): cache directory
- `squid_cache_size` (10000): cache dir size
- `squid_users` ([]): list of users (new format). Each entry may contain:
  - `username` (string)
  - `password` (string)
  - `whitelists` (list): names of entries from `squid_whitelist_domains` to allow for that user
  - `non_ssl_whitelist` (list): legacy per-user non-SSL domains (kept for compatibility)
  
  Legacy: `squid_auth_users` is still supported as a fallback for older vars.
- `squid_whitelist_domains` ([]): named lists of domains to reference from users and IPs. Example:
  - name: update-domains
    domains:
      - example.com
      - example.org
- `squid_ips` ([]): list of IP groups that may reference named whitelists. Each item:
  - `ips`: list of CIDRs/IPs
  - `whitelists`: list of named whitelist names
- `squid_acl_domains` ([]): list of ACLs to allow by domain: `{ name: "acl_name", domains: [".example.com"] }`
- `squid_ssl_bump_enabled` (false): enable SSL bumping
- `squid_ssl_bump_cert_path`, `squid_ssl_bump_key_path`: paths where the Squid server cert/key will be placed
- `squid_ssl_bump_client_cert`, `squid_ssl_bump_client_private_key`: client cert/key used to populate the NSS DB (when applicable)
- `squid_user`, `squid_group` (defaults: `proxy`): account used for `htpasswd` file ownership and to match your distribution (set to `squid` on some distros)
- `squid_conf_path` (`/etc/squid/squid.conf`): location the role writes the final config

Note on `squid_whitelist_domains` vs `squid_acl_domains`

- `squid_whitelist_domains` are named domain lists intended to be referenced by users or IP groups
  (via `squid_users` or `squid_ips`) and are primarily used for per-user/IP whitelisting and
  for SSL-bump splicing (when `squid_ssl_bump_enabled` is true). They are declared once and
  referenced by name (for example `update-domains_dstdomain` and `update-domains_servername`).

- `squid_acl_domains` is a separate list intended for global "allowed" domain ACLs —
  rules that simply permit traffic for those domains regardless of per-user/IP named lists.

Keeping these two concepts separate lets you define reusable named whitelists that can be
applied selectively to users or IP groups, while still having a set of global allowed domains.

## How to provide certificates and keys

The role copies certificate/key files from the role `files/` directory by basename. For example, if `squid_ssl_bump_cert_path` is `/etc/squid/ssl/squid.pem`, place a file named `squid.pem` in `roles/squid/files/` or set `squid_ssl_bump_cert_path` to a file path under `files/` and provide the matching basename. Alternatively set the variables to absolute paths pointing to files already present on the target.

Note: This role currently expects certificates/keys to be provided. I can add CA/cert generation if you want—ask and I will implement it.

## Example `squid_whitelist_domains`, `squid_users` and `squid_ips`

```yaml
squid_whitelist_domains:
  - name: update-domains
    domains:
      - example.com
      - example.org

squid_users:
  - username: alice
    password: alicepass
    whitelists:
      - update-domains

squid_ips:
  - ips:
      - 1.2.3.4
      - 1.2.4.5
    whitelists:
      - update-domains

squid_acl_domains:
  - name: allowed_sites
    domains:
      - .example.com
      - .internal.company.local
```

## IP whitelist examples

- Named whitelist applied to IP group (same as above):

```yaml
squid_whitelist_domains:
  - name: update-domains
    domains:
      - example.com

squid_ips:
  - ips:
      - 1.2.3.4
      - 1.2.4.5
    whitelists:
      - update-domains
```

- Legacy simple IP allow list (no named whitelists):

```yaml
squid_auth_mode: ip
squid_ip_allowed:
  - 10.0.0.0/24
  - 192.168.1.0/24
```

The first example shows how to reuse named domain lists for specific IP sets. The second
example demonstrates the legacy `squid_ip_allowed` which grants source-IP access globally.

## Example playbook

```yaml
- name: Configure Squid Proxy
  hosts: proxy_servers
  become: true
  roles:
    - role: squid
      vars:
        squid_port: 3128
        squid_users:
          - username: admin
            password: your_secure_password
            whitelists:
              - update-domains
        squid_whitelist_domains:
          - name: update-domains
            domains:
              - .no-inspect.example.com
        squid_acl_domains:
          - name: allowed_sites
            domains:
              - .example.com
        squid_ssl_bump_enabled: true
        squid_ssl_bump_cert_path: /etc/squid/ssl/squid.pem
        squid_ssl_bump_key_path: /etc/squid/ssl/squid.key
```

## Notes and tips

- The role installs `apache2-utils` and uses the `htpasswd` module to create `/etc/squid/passwd`. If your system uses a different `proxy` user, override `squid_user`/`squid_group`.
- For SSL bumping, per-user `whitelist` entries are added as `ssl::server_name` ACLs and spliced (not bumped) to avoid interception for those domains.
- If you prefer the role to generate a CA and server certificate automatically, I can add that feature (it is not implemented yet).

## License

MIT

## Author

Your Name Here
