
# setup:

## Marking traffic to and from 10.0.0.21

```sh
table inet qos {
  chain forward {
    type filter hook forward priority 0; policy accept;

    # Mark outgoing traffic TO 10.0.0.19
    ip daddr 10.0.0.19 meta mark set 10

    # Mark outgoing traffic FROM 10.0.0.19
    ip saddr 10.0.0.19 meta mark set 11
  }
}
```

## Egress to 10.0.0.21

```sh
tc qdisc del dev br-lan2 root 2>/dev/null
tc qdisc add dev br-lan2 root handle 1: htb default 30

# Root class — full link
tc class add dev br-lan2 parent 1: classid 1:1 htb rate 1gbit ceil 1gbit

# Guaranteed class for traffic TO 10.0.0.21
tc class add dev br-lan2 parent 1:1 classid 1:10 htb rate 10mbit ceil 1gbit
tc qdisc add dev br-lan2 parent 1:10 handle 110: fq_codel

# Default class
tc class add dev br-lan2 parent 1:1 classid 1:30 htb rate 1kbit ceil 1gbit
tc qdisc add dev br-lan2 parent 1:30 handle 130: fq_codel

# Filter based on nft mark
tc filter add dev br-lan2 parent 1: protocol ip prio 1 handle 10 fw flowid 1:10

```

## Egress from 10.0.0.21

```sh
tc qdisc del dev br-lan1 root 2>/dev/null
tc qdisc add dev br-lan1 root handle 1: htb default 30

tc class add dev br-lan1 parent 1: classid 1:1 htb rate 1gbit ceil 1gbit

# Guaranteed class for traffic FROM 10.0.0.21
tc class add dev br-lan1 parent 1:1 classid 1:11 htb rate 10mbit ceil 1gbit
tc qdisc add dev br-lan1 parent 1:11 handle 111: fq_codel

# Default class
tc class add dev br-lan1 parent 1:1 classid 1:30 htb rate 1kbit ceil 1gbit
tc qdisc add dev br-lan1 parent 1:30 handle 131: fq_codel

tc filter add dev br-lan1 parent 1: protocol ip prio 1 handle 11 fw flowid 1:11
```


