# nftables Ansible Role

This Ansible role provides a **direct, policy-driven firewall** using `nftables` on Linux hosts. It is designed for clarity, flexibility, and full control—no wrappers or abstractions—making it suitable for everything from simple host firewalls to complex multi-zone setups.

## Features

- **Direct nftables configuration**: No custom daemons or wrappers.
- **Multi-zone support**: Define zones, interfaces, and subnets.
- **SNAT/DNAT/NAT**: Masquerading, port forwarding, and advanced NAT.
- **Reusable IP sets**: Static or dynamic (DNS-resolved) sets.
- **Layered configuration**: Compose rules from multiple files or variable scopes.
- **Idempotent**: Safe to run repeatedly.

---

## Quick Start

1. **Install the role:**
   ```bash
   ansible-galaxy collection install hczv.firewall
   ```

2. **Assign the role:**
   ```yaml
   - hosts: firewall
     become: true
     roles:
       - hczv.firewall.nftables
   ```

3. **Define your firewall policy:**
   ```yaml
  
   nftables_chains:
     - name: input
       type: filter
       hook: input
       priority: filter
       policy: accept
       state:
         accept_loopback: true
         established: accept
         related: accept
         invalid: drop  
     - name: forward
       type: filter
       hook: forward
       priority: filter
       policy: drop
       state:
         established: accept
         related: accept
         invalid: drop
     - name: output
       type: filter
       hook: output
       priority: filter
       policy: accept

   nftables_zones:
     - name: wan
       interfaces: 
         - eth0
     - name: lan
       interfaces: 
         - eth1
         - eth2
       subnets: 
         - 10.0.0.0/24
         - 10.0.1.0/24
       allow_intrazone_traffic: true

   nftables_nat:
     - name: "masquerade lan to wan"
       type: snat
       source_zone: lan
       destination_zone: wan
       masquerade: true

   nftables_forward_rules:
     - name: allow web from lan to wan
       action: accept
       sources:
         - zone: lan
           subnets: true
       destinations:
         - zone: wan
       destination_ports:
         tcp: 
           80
           443
   ```

---

## Variables

All configuration is done via variables. The main variables are:

| Variable                   | Type        | Purpose                                      |
|----------------------------|-------------|----------------------------------------------|
| `nftables_chains`          | list[dict]  | Chains and state options                     |
| `nftables_zones`           | list[dict]  | Define network zones and interfaces          |
| `nftables_sets`            | list[dict]  | Named sets of IPs/subnets                    |
| `nftables_dnsmasq_sets`    | list[dict]  | DNS-resolved sets (dynamic IPs)              |
| `nftables_nat`             | list[dict]  | SNAT/DNAT/NAT rules                          |
| `nftables_input_rules`     | list[dict]  | Inbound rules (per zone)                     |
| `nftables_forward_rules`   | list[dict]  | Forwarding rules (cross-zone)                |

### Example: Zone Definition

```yaml
nftables_zones:
  - name: lan
    interfaces: 
      - eth1
      - eth2
    subnets: 
      - 10.0.0.0/24
    allow_intrazone_traffic: true
```

### Example: NAT

```yaml
nftables_nat:
  - name: "masquerade lan to wan"
    type: snat
    source_zone: lan
    destination_zone: wan
    masquerade: true
```

### Example: Rule

```yaml
nftables_input_rules:
  - name: allow ssh from lan
    zone: lan
    action: accept
    sources:
      subnets: true
    destination_ports:
      tcp: 
        - 22
```

---

## Advanced: Layered Variable Merging

You can split configuration across multiple files or variable scopes. Variables with suffixes (`_0`, `_1`, ..., `_9`) are merged into the base variable. This enables modular, multi-file, and environment-specific setups.

**Example:**

```yaml
# group_vars/all.yml
nftables_input_rules:
  - name: allow ping
    zone: lan
    action: accept
    destination_ports:
      icmp:
        - echo-request

# group_vars/prod.yml
nftables_input_rules_1:
  - name: allow ssh
    zone: lan
    action: accept
    destination_ports:
      tcp: 
        - 22
```

Result: Both rules are applied.

---

## Compatibility

- **OS:** AlmaLinux 9+, RHEL 9+, CentOS Stream 9+, Debian/Ubuntu (see molecule tests)
- **Requires:** Ansible 2.9+, `nftables` package

---

## More Examples

See the [molecule](./molecule/) scenarios and `group_vars` files for real-world configurations.

---

## License

MIT

---

## Author

[github.com/hczv](https://github.com/hczv)
