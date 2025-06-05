# nftables

This role configures nftables firewall without any wrappers.

Can be used for:
* router firewalls
* host firewalls

## Setup

* Install role
```
ansible-galaxy collection install hczv.firewall
```

* Assign role to host
```
- hosts: firewall
  become: true
  roles
    - hczv.firewall.nftables
```

* Define global config

```yaml
nftables_global:
  default_policy:
    input: accept   # Optinal, defaults to accept
    forward: drop   # Optional, defaults to drop
    output: accept  # Optional, defaults to accept
  logging:          # Not implemented
    enabled: true   # -
    level: info     # -
  rate_limit: 1000  # Not implemented
  counter: true     # Not implemented
```

## Example config for home firewall

* Define zones
```yaml
nftables_zones:
  - name: wan    # Required, zone name
    interfaces:  # Required, Interfaces in this zone
      - eth0
  - name: lan    # Required, zone name
    interfaces:  # Required, Interfaces in this zone
      - eth1
      - eth2
    subnets:     # Optional, subnets in this zone - used for zone-based rules
      - 10.0.0.0/24
      - 10.0.1.0/24
    allow_intrazone_traffic: true  # Optional, default false - allows all traffic between subnets/interfaces in the same zone
  - name: lab    # Required, zone name
    interfaces:  # Required, Interfaces in this zone
      - eth3
      - eth4
    subnets:  # Optional, subnets in this zone - used for zone-based rules
      - 10.13.33.0/24
      - 10.14.44.0/24
    allow_intrazone_traffic: false
```

* Define nat masquerade rules
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

* Define sets
```yaml
nftables_sets:
  - name: any
    subnets:
      - 0.0.0.0/0
```

* Define forward rules
```yaml
nftables_forward_rules:
  - name: allow ssh traffic from lan
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
    # Can also be limited to specific ports by adding the "destination_ports" key
    # If destination_ports isnt defined, it'll allow all ports.
    destination_ports:
      tcp:
        - 80
        - 443
```

## Port forwarding

* Define dnat rule
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
        - destination_port: 8080
          to_port: 8080
        - destination_port: 8088
          to_port: 8088
      udp:
        - destination_port: 123
          to_port: 123
```

* Allow dnat traffic in the forward chain
```yaml
nftables_forward_rules:
  - name: Allow wan to internal web server
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
        - 8080
        - 8088
      udp:
        - 123
```


## More example configs:

```yaml
---
# This file is an example configuration for nftables.
nftables_global:
  default_policy:
    input: accept
    forward: drop
    output: accept
  logging:
    enabled: true
    level: info
  rate_limit: 1000
  counter: true

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
        - destination_port: 8080
          to_port: 8081
        - destination_port: 8080
          to_port: 8082
      udp:
        - destination_port: 8089
          to_port: 800
nftables_sets:
  - name: any
    subnets:
      - 0.0.0.0/0
  - name: wan_ip
    subnets:
      - 10.11.0.1
  - name: lan_host
    subnets:
      - 10.0.0.2

nftables_dnsmasq_sets:
  - name: external-hosts-example
    hosts:
      - google.dk
      - yahoo.dk

nftables_input_rules:
  - name: allow ssh from known good
    zone: lan
    action: accept
    sources:
      sets:
        - wan_ip
      subnets: true
    destination_ports:
      tcp:
        - 22
        - 24
      udp:
        - 23

nftables_forward_rules:
  - name: allow ssh traffic from lan
    action: accept
    sources:
      - zone: lan
        subnets: true
        sets:
          - external-hosts-example
          - wan_ip
    destinations:
      - zone: wan
        sets:
          - wan_ip
      - zone: wan
        sets:
          - external-hosts-example
      - zone: lab
        subnets: true
    destination_ports:
      tcp:
        - 22

```
