# 🔥 nftables Ansible Role


- [🔥 nftables Ansible Role](#-nftables-ansible-role)
  - [🚀 Quick Start](#-quick-start)
    - [🔧 Install the role](#-install-the-role)
    - [🧩 Assign the role to hosts](#-assign-the-role-to-hosts)
    - [🌐 Define global firewall behavior](#-define-global-firewall-behavior)
  - [🏡 Home Firewall Example](#-home-firewall-example)
    - [🔲 Define network zones](#-define-network-zones)
    - [🔁 NAT Masquerading](#-nat-masquerading)
    - [📦 Define reusable IP sets](#-define-reusable-ip-sets)
    - [📤 Allow Forwarded Traffic](#-allow-forwarded-traffic)
  - [🔍 Specification](#-specification)
    - [`nftables_global` (dict)](#nftables_global-dict)
      - [`default_policy` keys:](#default_policy-keys)
    - [`nftables_zones` (list of dicts)](#nftables_zones-list-of-dicts)
    - [`nftables_nat` (list of dicts)](#nftables_nat-list-of-dicts)
    - [`nftables_sets` (list of dicts)](#nftables_sets-list-of-dicts)
    - [`nftables_dnsmasq_sets` (list of dicts)](#nftables_dnsmasq_sets-list-of-dicts)
    - [`nftables_forward_rules` and `nftables_input_rules` (list of dicts)](#nftables_forward_rules-and-nftables_input_rules-list-of-dicts)
      - [`sources` / `destinations` entry:](#sources--destinations-entry)
      - [destination\_ports example:](#destination_ports-example)
  - [🔁 Port Forwarding Example](#-port-forwarding-example)
    - [🎯 DNAT Rule](#-dnat-rule)
    - [✅ Allow Forwarded DNAT Traffic](#-allow-forwarded-dnat-traffic)
  - [🧪 Full Example Config](#-full-example-config)


This Ansible role configures a powerful, policy-driven `nftables` firewall **without any wrappers or abstractions** — giving you full control and visibility.

Supports use cases like:

- 🏠 Home or Lab Routers  
- 🛡️ Host-level Firewalls  
- 🧩 Complex multi-zone setups  

---

## 🚀 Quick Start

### 🔧 Install the role

```bash
ansible-galaxy collection install hczv.firewall
```

### 🧩 Assign the role to hosts

```yaml
- hosts: firewall
  become: true
  roles:
    - hczv.firewall.nftables
```

### 🌐 Define global firewall behavior

```yaml
nftables_global:
  default_policy:
    input: accept     # Optional (default: accept)
    forward: drop     # Optional (default: drop)
    output: accept    # Optional (default: accept)
```

## 🏡 Home Firewall Example

### 🔲 Define network zones

```yaml
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

  - name: lab
    interfaces:
      - eth3
      - eth4
    subnets:
      - 10.13.33.0/24
      - 10.14.44.0/24
    allow_intrazone_traffic: false
```

### 🔁 NAT Masquerading

```yaml
nftables_nat:
  - name: "masquerade lan to wan"
    type: snat
    source_zone: lan
    destination_zone: wan
    masquerade: true

  - name: "masquerade lab to wan"
    type: snat
    source_zone: lab
    destination_zone: wan
    masquerade: true
```

### 📦 Define reusable IP sets

```yaml
nftables_sets:
  - name: any
    subnets:
      - 0.0.0.0/0
```

### 📤 Allow Forwarded Traffic

```yaml
nftables_forward_rules:
  - name: allow web from lan and lab to wan
    action: accept
    sources:
      - zone: lan
        subnets: true
      - zone: lab
        subnets: true
    destinations:
      - zone: wan
        sets:
          - any
    destination_ports: # if destination_ports is omitted, it'll open for all ports
      tcp:
        - 80
        - 443
```

## 🔍 Specification

Top level keys

| Key                      | Type        | Description                          |
| ------------------------ | ----------- | ------------------------------------ |
| `nftables_global`        | dict        | Default policy & system-wide flags   |
| `nftables_zones`         | list\[dict] | Interface/subnet zone definitions    |
| `nftables_sets`          | list\[dict] | Static subnet/IP sets                |
| `nftables_dnsmasq_sets`  | list\[dict] | DNS-resolved IP sets (planned)       |
| `nftables_nat`           | list\[dict] | SNAT/DNAT rules including masquerade |
| `nftables_input_rules`   | list\[dict] | Inbound rules by zone                |
| `nftables_forward_rules` | list\[dict] | Cross-zone forwarding rules          |


Below is a specification of valid keys and expected types for each top-level configuration variable.

### `nftables_global` (dict)

| Key             | Type    | Default   | Description                             |
|------------------|---------|-----------|-----------------------------------------|
| `default_policy` | dict    | see below | Sets default policy per chain           |
| `logging`        | dict    | not used  | Reserved for future use                 |
| `rate_limit`     | int     | not used  | Reserved for future use                 |
| `counter`        | bool    | not used  | Reserved for future use                 |

#### `default_policy` keys:

| Key     | Type   | Default | Options     |
|---------|--------|---------|-------------|
| `input` | string | accept  | accept/drop |
| `forward` | string | drop | accept/drop |
| `output` | string | accept | accept/drop |

---

### `nftables_zones` (list of dicts)

Each zone must include a name and at least one interface.

| Key                     | Type        | Required | Description                             |
|--------------------------|-------------|----------|-----------------------------------------|
| `name`                  | string      | ✅       | Unique zone name                        |
| `interfaces`            | list[string]| ✅       | Interface names (e.g., `eth0`)          |
| `subnets`               | list[string]| ❌       | Optional subnets in this zone           |
| `allow_intrazone_traffic` | bool     | ❌       | Allow traffic within zone               |

---

### `nftables_nat` (list of dicts)

Defines NAT (SNAT or DNAT) behavior.

| Key              | Type     | Required | Description                            |
|------------------|----------|----------|----------------------------------------|
| `name`           | string   | ✅       | Rule description                       |
| `type`           | string   | ✅       | `snat` or `dnat`                       |
| `source_zone`    | string   | ✅       | Zone where traffic originates          |
| `destination_zone` | string | ✅ (SNAT)| Where traffic is going                 |
| `masquerade`     | bool     | ✅ (SNAT)| If true, performs masquerading         |
| `source_set`     | string   | ❌ (DNAT)| Match source IP set                    |
| `destination_set`| string   | ❌ (DNAT)| Match destination IP set               |
| `dnat_zone`      | string   | ✅ (DNAT)| Target zone for forwarded traffic      |
| `dnat_set`       | string   | ✅ (DNAT)| IP set of internal destination         |
| `ports`          | dict     | ❌       | TCP/UDP port mappings                  |

---

### `nftables_sets` (list of dicts)

Reusable named sets of subnets or IPs.

| Key       | Type          | Required | Description                        |
|-----------|---------------|----------|------------------------------------|
| `name`    | string        | ✅       | Set name                           |
| `subnets` | list[string]  | ✅       | List of IPs or CIDRs               |

---

### `nftables_dnsmasq_sets` (list of dicts)

DNS-resolved sets used for dynamic IPs (not implemented).

| Key    | Type         | Required | Description                       |
|--------|--------------|----------|-----------------------------------|
| `name` | string       | ✅       | Set name                          |
| `hosts`| list[string] | ✅       | List of domain names              |

---

### `nftables_forward_rules` and `nftables_input_rules` (list of dicts)

Rules for forwarded or inbound traffic. The structure is similar for both.

| Key               | Type          | Required | Description                        |
|--------------------|---------------|----------|------------------------------------|
| `name`            | string        | ✅       | Rule description                   |
| `zone`            | string        | ✅ (input rules) | Zone traffic is coming into |
| `action`          | string        | ✅       | `accept`, `drop`, `reject`         |
| `sources`         | list[dict]    | ❌       | Match by zone, subnet, or sets     |
| `destinations`    | list[dict]    | ❌       | Match target zone, subnet, or sets |
| `destination_ports`| dict        | ❌       | Ports to match (per protocol) if undefined or empty, will allow all protocols and ports     |

#### `sources` / `destinations` entry:

```yaml
- zone: lan
  sets:
    - my_set
  subnets: true
```
- zone: string (optional)
- sets: list of set names (optional)
- subnets: bool — match declared subnets in the zone

#### destination_ports example:

```yaml
destination_ports:
  tcp:
    - 22
    - 443
  udp:
    - 53
```


## 🔁 Port Forwarding Example

### 🎯 DNAT Rule

```yaml
nftables_nat:
  - name: "DNAT to internal web server"
    type: dnat
    source_zone: wan
    source_set: any
    destination_set: wan_ip
    dnat_zone: lan
    dnat_set: lan_host
    ports:
      tcp:
        - destination_port: 443
          to_port: 8443
```

### ✅ Allow Forwarded DNAT Traffic

```yaml
nftables_forward_rules:
  - name: Allow DNAT web server traffic
    action: accept
    sources:
      - zone: wan
        sets:
          - any
    destinations:
      - zone: lan
        sets:
          - lan_host
    destination_ports:
      tcp:
        - 8443
```

## 🧪 Full Example Config

```yaml
nftables_global:
  default_policy:
    input: accept
    forward: drop
    output: accept

nftables_zones:
  - name: wan
    interfaces: [eth0]
  - name: lan
    interfaces: [eth1, eth2]
    subnets: [10.0.0.0/24, 10.0.1.0/24]
    allow_intrazone_traffic: true
  - name: lab
    interfaces: [eth3, eth4]
    subnets: [10.13.33.0/24, 10.14.44.0/24]
    allow_intrazone_traffic: true

nftables_nat:
  - name: "snat lan to wan"
    type: snat
    source_zone: lan
    destination_zone: wan
    masquerade: true

  - name: "DNAT to internal web server"
    type: dnat
    source_zone: wan
    source_set: any
    destination_set: wan_ip
    dnat_zone: lan
    dnat_set: lan_host
    ports:
      tcp:
        - destination_port: 443
          to_port: 8443

nftables_sets:
  - name: any
    subnets: [0.0.0.0/0]
  - name: wan_ip
    subnets: [10.11.0.1]
  - name: lan_host
    subnets: [10.0.0.2]

nftables_dnsmasq_sets:
  - name: external-hosts-example
    hosts:
      - google.com
      - yahoo.com

nftables_input_rules:
  - name: allow ssh from lan
    zone: lan
    action: accept
    sources:
      subnets: true
    destination_ports:
      tcp: [22]

nftables_forward_rules:
  - name: allow internet from lan
    action: accept
    sources:
      - zone: lan
        subnets: true
    destinations:
      - zone: wan
        sets: [any]
```
