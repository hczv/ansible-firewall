FROM almalinux:9.4

ARG USERNAME=vscode
ARG USERID=1000
ARG GROUPID=1000

# Upgrade packages and install new packages
RUN dnf upgrade -y
RUN python3 -m ensurepip --upgrade
RUN dnf install -y epel-release
RUN dnf install -y python3-devel gcc make git fish neofetch wget util-linux util-linux-user which vim powerline powerline-fonts vim-powerline sudo sshpass python3-tkinter htop procps rsync netcat

# Create VSCode user
RUN groupadd --gid ${GROUPID} ${USERNAME}
RUN useradd --comment "VSCode User Account" --gid ${GROUPID} --uid ${USERID} -p ${USERNAME} -G wheel -s /usr/bin/bash -m ${USERNAME}

# Allow wheel to perform sudo actions with no password
RUN sed -e 's/^%wheel/#%wheel/g' -e 's/^# %wheel/%wheel/g' -i /etc/sudoers

# Load custom userconfig .bashrc
RUN echo '[ -f /userconfig/.bashrc ] && source /userconfig/.bashrc' >> "/home/$USERNAME/.bashrc"

# Ensure bash history
RUN mkdir /userconfig && \
    chown -R $USERNAME /userconfig

# Install fzf
RUN wget https://github.com/junegunn/fzf/releases/download/v0.54.0/fzf-0.54.0-linux_amd64.tar.gz -P /tmp && \
    tar -zxvf /tmp/fzf-0.54.0-linux_amd64.tar.gz -C /usr/local/bin && \
    rm -f /tmp/fzf-0.54.0-linux_amd64.tar.gz

# Install docker-ce cli
RUN dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo && \
    dnf install -y docker-ce-cli && \
    groupdel docker
#    usermod -aG docker $USERNAME

#RUN dnf install -y yum-utils device-mapper-persistent-data lvm2 && \
#    dnf  config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && \
#    dnf install -y docker-ce docker-ce-cli containerd.io && \
#    usermod -aG docker $USERNAME

# Set workdir to vscode home
WORKDIR /home/${USERNAME}

# Install Pypi packages for VSCode user
RUN runuser -l ${USERNAME} -c "mkdir -p /home/${USERNAME}/.local/bin"
RUN runuser -l ${USERNAME} -c "python3 -m pip install --user --upgrade pip"
#RUN runuser -l ${USERNAME} -c "pip3 install ansible ansible-navigator ansible-lint yamllint"
