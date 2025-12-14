# Ansible Role: nftables

This Ansible role provides a comprehensive solution for managing `nftables` rules on Linux systems. It simplifies the configuration of firewall rules, network address translation (NAT), and routing policies, offering a flexible and modular approach to network security.

## Features

*   **Dynamic Rule Generation**: Define `nftables` chains, sets, and rules using Ansible variables.
*   **Zone-based Filtering**: Implement firewall rules based on custom-defined network zones and interfaces.
*   **IP Set Management**: Utilize IP sets for efficient matching of IP addresses, including dynamic updates from URLs.
*   **DNS-based Sets**: Integrate with `dnsmasq` to create IP sets from DNS records.
*   **Policy-Based Routing (PBR)**: Configure Linux routing tables and apply PBR rules with `nftables`.
*   **Variable Merging**: Easily extend and override `nftables` configurations across different hosts and groups.

## Requirements

*   Ansible
*   A Linux system with nftables installed.

## Role Variables

This role utilizes several variables to configure `nftables` rules. These variables are typically defined in `defaults/main.yml`, `group_vars/`, `host_vars/`, or directly within your playbooks. Key variables include:

### `nftables_chains`

This variable defines the `nftables` chains to be present in the configuration, along with their settings:

*   `name`: The name of the chain (e.g., `input`, `forward`, `output`). Required.
*   `type`: The type of the chain (`filter` or `nat`). Required.
*   `hook`: The hook point for the chain (`input`, `forward`, `output`, `prerouting`, `postrouting`). Required.
*   `priority`: The priority of the chain (e.g., `filter`). Required.
*   `policy`: The default policy for the chain (`accept` or `drop`). Required.
*   `state`: A dictionary of connection tracking states to apply to the chain. This allows for stateful firewall rules. Common options include:
    *   `established`: Matches packets that belong to an established connection.
    *   `related`: Matches packets that are new but related to an existing connection.
    *   `invalid`: Matches packets that do not have a valid state.
    *   `accept_loopback`: Specifically accepts traffic on the loopback interface.
    Optional.

_example:_

```yaml
# chain definition
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
```


### `nftables_zones`

`nftables` does not inherently support zones, but this role implements a zone-like system to group interfaces. This allows for filtering rules based on these defined zones.

Settings:
*   `name`: Name of the zone, used to reference it in rules (required).
*   `interfaces`: List of network interfaces belonging to this zone (required).
*   `subnets`: List of subnets associated with the interfaces in this zone (optional). If not defined, the `subnets` option cannot be used when referencing this zone in `nftables_rules`.

_example:_

```yaml
# Zone definition
nftables_zones:
  - name: wan
    interfaces:
      - eth0
  - name: app
    interfaces:
      - eth1
    subnets:
      - "10.0.0.0/24"
  - name: dmz
    interfaces:
      - eth2
    subnets:
      - "10.0.33.0/24"
```

### `nftables_sets`

Defines `nftables` sets, which can be used in `nftables_rules` to group IP addresses or networks.

Settings:
*   `name`: Name of the set, used to reference it in rules (required).
*   `urls`: List of URLs from which IP addresses will be fetched and added to the set. The role ensures daily refreshment of these IPs (optional).
*   `subnets`: List of IP addresses and/or subnets to include in the set (optional).

_example:_

```yaml
nftables_sets:
  - name: geoip_us
    urls:
      - https://raw.githubusercontent.com/herrbischoff/country-ip-blocks/refs/heads/master/ipv4/us.cidr
  - name: dns
    subnets:
      - 1.1.1.1
      - 9.9.9.9
  - name: blocklist
    urls:
      - https://iplists.firehol.org/files/firehol_level1.netset
      - https://iplists.firehol.org/files/firehol_level2.netset
      - https://iplists.firehol.org/files/firehol_level3.netset
      - https://iplists.firehol.org/files/firehol_level4.netset
  - name: trusted-subnets
    subnets:
      - "10.0.33.0/24"
```


### `nftables_dnsmasq_sets`

This variable integrates with the `dnsmasq` role within this collection. For correct operation, both the `nftables` and `dnsmasq` roles must be deployed to the same host (typically a firewall/router).

Settings:
*   `name`: Name of the set, used to reference it in rules (required).
*   `hosts`: List of DNS records whose resolved IP addresses will populate this set (required).

_example:_

```yaml
nftables_dnsmasq_sets:
  - name: external-hosts-example
    hosts:
      - google.com
      - yahoo.com
```


### `nftables_routing_tables`

Allows for the creation of Linux routing tables, which can be referenced in `nftables` rules for Policy-Based Routing (PBR).

Settings:
*   `name`: Name of the routing table (required).
*   `id`: Unique routing table ID (required).
*   `mark`: Mark associated with the table (required).

_example:_

```yaml
nftables_routing_tables:
  - name: pbr
    id: 321
    mark: "0x3"
```

### `nftables_rules`

Defines the `nftables` rules that will be applied to the remote host.

Settings:
*   `name`: A descriptive name for the rule (required).
*   `chain`: The `nftables` chain to which this rule belongs (required). The chain must be defined in `nftables_chains`.
*   `operations`: Custom operations to perform on matching traffic (optional). Available operations include:
    *   `redirect`: Redirects traffic to a different destination.
    *   `ct_mark_set`: Sets the connection track mark.
    *   `meta_mark_set`: Sets the packet mark.
    *   `masquerade`: Performs Source Network Address Translation (SNAT) to hide the origin of packets.
    *   `dnat_to`: Performs Destination Network Address Translation (DNAT) to redirect incoming traffic to a different destination.
*   `action`: The action to take for traffic matching the rule (`accept`, `drop`, or `reject`). Required.
*   `sources`: A list of criteria to match the source of the traffic (optional).
*   `destinations`: A list of criteria to match the destination of the traffic (optional).
*   `protocols`: Protocols and ports to match the traffic (optional).

Each item within `sources` and `destinations` can contain the following settings:

*   `zone`: The name of a defined zone (from `nftables_zones`) to match the traffic's ingress/egress interface (optional).
*   `subnets`: A boolean indicating whether to match the subnets defined within the specified `zone` (optional). Requires `subnets` to be defined in the corresponding `nftables_zones` entry.
*   `sets`: A list of `nftables` sets (from `nftables_sets`) to match against the source/destination IP addresses (optional).

_examples:_

```yaml
nftables_rules:
  - name: allow ssh from lan and trusted sources
    chain: input
    action: accept
    sources:
      # This matches subnets defined in nftables_zones `lan` and from the interfaces in the lan zone
      - zone: lan
        subnets: true
      # This matches trusted-subnets ips/subnets irrespective of the source interface
      - sets:
          - trusted-subnets
    protocols:
      tcp:
        - 22
      # allows icmp ping
      icmp:
        - echo-request
```


## Variable Merging

All the `nftables` properties listed above (`nftables_chains`, `nftables_zones`, `nftables_sets`, `nftables_dnsmasq_sets`, `nftables_routing_tables`, and `nftables_rules`) support merging. This feature allows you to append additional configurations by adding a suffix to the variable name, for example:

*   `nftables_sets`
*   `nftables_sets_gateway`
*   `nftables_sets_default`

All items defined in these suffixed lists will be merged into a single comprehensive list when generating the `nftables` configuration. This is particularly useful for sharing common firewall rules across multiple hosts while also allowing for host-specific or group-specific configurations.

The order of merged rules is determined by the variable name: `nftables_rules` is processed first, followed by suffixed variables sorted alphanumerically (e.g., `_0` before `_9`, then `_a` before `_z`).


# Full Example for Managing nftables Across an Environment (Router/Firewall)

This section provides a comprehensive example of how to manage `nftables` configurations across an environment, including a router/firewall host.

inventory:

```ini
[firewall]
firewall ansible_host=10.0.0.1

[app]
app01 ansible_host=10.0.0.10
app02 ansible_host=10.0.0.11

[loadbalancer]
lb01 ansible_host=10.0.33.10
```

Playbook to deploy roles (`hczv.firewall.nftables` and `hczv.firewall.dnsmasq`):

```yaml
- hosts: firewall
  become: true
  roles:
    - hczv.firewall.dnsmasq
    - hczv.firewall.nftables
```

## Define Default Variables Across All Servers

These variables define the default `nftables` properties and rules to apply to all servers. These can be overridden in `group_vars/` or `host_vars/` as needed.

`nftables` chains to be defined across all hosts (`group_vars/all/nftables_chains.yml`):

```yaml
nftables_chains_input:
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

nftables_chains_forward:
  - name: forward
    type: filter
    hook: forward
    priority: filter
    policy: drop
    state:
      established: accept
      related: accept
      invalid: drop

nftables_chains_output:
  - name: output
    type: filter
    hook: output
    priority: filter
    policy: accept
```

`nftables` zones to be defined across all hosts (`group_vars/all/nftables_zones.yml`)

```yaml
nftables_zones:
  - name: lan
    interfaces:
      - eth0 # assuming all hosts uses eth0 as their interface
```

`nftables` sets (`group_vars/all/nftables_sets.yml`)

```yaml
nftables_sets:
  - name: any
    subnets:
      - "0.0.0.0/0"
  - name: rfc_1918
    subnets:
      - "10.0.0.0/8"
      - "172.16.0.0/12"
      - "192.168.0.0/16"
  - name: firewall
    subnets:
      - "10.0.0.1"
  - name: app
    subnets:
      - "10.0.0.10"
      - "10.0.0.11"
  - name: loadbalancer
    subnets:
      - "10.0.33.10"
  - name: management_network
    subnets:
      - "10.0.99.0/24"
```

`nftables` rules (`group_vars/all/nftables_rules.yml`)

```yaml
nftables_rules_input:
  - name: allow ssh from management network
    chain: input
    action: accept
    sources:
    - zone: lan
      subnets: false
      sets:
        - management_network
    protocols:
      tcp:
        - 22
      icmp:
        - echo-request

# This rule will always be at the end based on the _zz identifier.
nftables_rules_input_zz:
  - name: default deny
    chain: input
    action: drop
```

## Firewall Configuration

For the firewall, we'll define an additional `postrouting` chain for NAT. This will be merged with the default chains.

`group_vars/firewall/nftables_chains.yml`:

```yaml
nftables_chains_postrouting:
  - name: postrouting
    type: nat
    hook: postrouting
    priority: srcnat
    policy: accept
```

The firewall will have different zones than a normal server, so these will override the default `nftables_zones` (`group_vars/firewall/nftables_zones.yml`):

```yaml
nftables_zones:
  - name: wan
    interfaces:
      - eth0 # Replace with your WAN interface
  - name: app
    interfaces:
      - eth1 # Replace with your APP interface
    subnets:
      - "10.0.0.0/24" # Replace with your APP subnet
  - name: dmz
    interfaces:
      - eth2 # Replace with your DMZ interface
    subnets:
      - "10.0.33.0/24" # Replace with your DMZ subnet
  - name: management
    interfaces:
      - eth3 # Replace with your Management interface
    subnets:
      - "10.0.88.0/24" # Replace with your Management subnet
```

Define some `nftables` sets for the firewall, including geo-IP and blocklists (`group_vars/all/nftables_sets.yml`):

```yaml
nftables_sets_firewall:
  - name: geoip_us
    urls:
      - https://raw.githubusercontent.com/herrbischoff/country-ip-blocks/refs/heads/master/ipv4/us.cidr
  - name: blocklist_ips
    urls:
      - https://iplists.firehol.org/files/firehol_level1.netset
```

Define `postrouting` NAT rules (a separate `forward` rule is still needed to allow the traffic):

Example `group_vars/firewall/nftables_rules_postrouting.yml`:

```yaml
nftables_rules_postrouting:
  - name: Masquerade outbound traffic
    chain: postrouting
    operations:
      - masquerade: true
    sources:
      - zone: app
        subnets: true
      - zone: dmz
        subnets: true
      - zone: management
        subnets: true
    destinations:
      - zone: wan
        sets:
          - any
```

Define `prerouting` port forwarding rules (this only maps the traffic; a separate `forward` rule is still needed to allow the traffic):

`group_vars/firewall/nftables_rules_prerouting.yml`:

```yaml
nftables_rules_prerouting:
  - name: dnat 443 to loadbalancer
    chain: prerouting
    operations:
      - dnat_to: 10.0.33.10:443
    sources:
      - zone: wan
        sets:
          - any
      - zone: management
        subnets: true
    protocols:
      tcp:
        - 443
```

`nftables` input rules for the firewall:

`group_vars/firewall/nftables_rules_input.yml`:

```yaml
nftables_rules_input:
  - name: allow ssh from management network
    chain: input
    action: accept
    sources:
      - zone: management
        subnets: true
    protocols:
      tcp:
        - 22
      icmp:
        - echo-request

  - name: allow dns requests
    chain: input
    action: accept
    sources:
      - zone: app
        subnets: true
      - zone: dmz
        subnets: true
      - zone: management
      subnets: true
    protocols:
      tcp:
        - 53
      udp:
        - 53
```

`nftables` forward rules for the firewall:

`group_vars/firewall/nftables_rules_forward.yml`:

```yaml
nftables_rules_forward:
  - name: allow from local zones to wan
    chain: forward
    action: accept
    sources:
      - zone: app
        subnets: true
      - zone: dmz
        subnets: true
      - zone: management
        subnets: true
    destinations:
      - zone: wan
        sets:
          - any

- name: drop blacklist wan to loadbalancer
    chain: forward
    action: drop
    sources:
      - zone: wan
        sets:
          - blocklist
    destinations:
      - zone: dmz
        subnets: false
        sets:
          - loadbalancer
    protocols:
      tcp:
        - 443

  - name: allow geoip_us to loadbalancer
    chain: forward
    action: accept
    sources:
      - zone: wan
        subnets: false
        sets:
          - geoip_us
    destinations:
      - zone: dmz
        subnets: false
        sets:
          - loadbalancer
    protocols:
      tcp:
        - 443
```

