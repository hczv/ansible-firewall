# Ansible Squid Role

This role installs and configures Squid proxy server with user authentication, domain-based access control, HTTP/HTTPS proxying, SSL bumping, and whitelisting capabilities.

## Requirements

This role requires Ansible 2.9 or higher.

## Role Variables

Below is a list of variables that can be configured for this role, along with their default values and descriptions.

```yaml
# defaults file for ansible-squid
squid_port: 3128
squid_cache_dir: /var/spool/squid
squid_cache_size: 10000
squid_max_object_size: 4096 KB
squid_max_object_size_in_memory: 512 KB

squid_auth_users: []
  # Example:
  # - username: user1
  #   password: password1

squid_acl_domains: []
  # Example:
  # - name: allowed_domains
  #   domains:
  #     - .google.com
  #     - .github.com

squid_ssl_bump_enabled: false
squid_ssl_bump_cert_country: "US"
squid_ssl_bump_cert_state: "Some-State"
squid_ssl_bump_cert_locality: "Some-City"
squid_ssl_bump_cert_organization: "Ansible Squid"
squid_ssl_bump_cert_organizational_unit: "IT"
squid_ssl_bump_cert_common_name: "Ansible Squid Proxy"
squid_ssl_bump_generate_cert: true
squid_ssl_bump_cert_path: "/etc/squid/ssl/squid.pem"
squid_ssl_bump_key_path: "/etc/squid/ssl/squid.key"
squid_ssl_bump_client_private_key: "/etc/squid/ssl_cert/squid_priv.pem"
squid_ssl_bump_client_cert: "/etc/squid/ssl_cert/squid_cert.pem"
squid_ssl_bump_client_cert_dir: "/etc/squid/ssl_cert"
squid_ssl_bump_client_cert_db_dir: "/var/lib/ssl_db"

squid_ssl_bump_whitelist: []
  # Example:
  # - .whitelisted-domain.com
```

## Dependencies

None.

## Example Playbook

```yaml
- name: Configure Squid Proxy
  hosts: proxy_servers
  become: true
  roles:
    - role: squid
      vars:
        squid_port: 3128
        squid_auth_users:
          - username: admin
            password: your_secure_password
          - username: guest
            password: another_secure_password
        squid_acl_domains:
          - name: allowed_sites
            domains:
              - .example.com
              - .anothersite.org
        squid_ssl_bump_enabled: true
```

## Usage

1.  **Define Users and Passwords:** Populate the `squid_auth_users` variable with a list of dictionaries, each containing a `username`, `password`, an optional `whitelist` (a list of domains to exclude from SSL bumping for that specific user), and an optional `non_ssl_whitelist` (a list of non-SSL domains to allow access for that specific user).
2.  **Define Allowed Domains:** Populate the `squid_acl_domains` variable with a list of dictionaries. Each dictionary should have a `name` for the ACL and a `domains` list containing the domains to allow.
3.  **Enable SSL Bumping:** Set `squid_ssl_bump_enabled` to `true` to enable HTTPS inspection. You must provide the SSL certificate and key paths using `squid_ssl_bump_cert_path` and `squid_ssl_bump_key_path` respectively. Similarly, provide the client SSL certificate and private key paths using `squid_ssl_bump_client_cert` and `squid_ssl_bump_client_private_key`.
4.  **Whitelist Domains for SSL Bumping (Per-User):** For specific users, add a `whitelist` key to their entry in `squid_auth_users` with a list of domains to exclude from SSL bumping for that user.
5.  **Whitelist Non-SSL Domains (Per-User):** For specific users, add a `non_ssl_whitelist` key to their entry in `squid_auth_users` with a list of non-SSL domains to allow access for that user.
6.  **Run the Playbook:** Execute your Ansible playbook targeting your proxy servers.

## License

MIT

## Author Information

Your Name Here
