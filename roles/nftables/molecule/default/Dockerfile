FROM almalinux:9.4

ARG USERNAME=molecule
ARG USERID=1000
ARG GROUPID=1000

RUN dnf install -y nftables iptables sudo iproute-tc
RUN groupadd --gid ${GROUPID} ${USERNAME}
RUN useradd --comment "molecule account" --gid ${GROUPID} --uid ${USERID} -p ${USERNAME} -G wheel -s /usr/bin/bash -m ${USERNAME}

# Allow wheel to perform sudo actions with no password
RUN sed -e 's/^%wheel/#%wheel/g' -e 's/^# %wheel/%wheel/g' -i /etc/sudoers

COPY files/systemctl3.py /usr/bin/systemctl3.py
RUN cp /usr/bin/systemctl3.py /usr/bin/systemctl

USER molecule
