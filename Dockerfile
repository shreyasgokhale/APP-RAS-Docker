# From Ubuntu 16
FROM ubuntu:xenial


# install essential packages
RUN apt-get update && apt-get install -q -y \
    dirmngr \
    gnupg2 \
    wget \
    build-essential \
    cmake git \
    zlib1g-dev \
    libssl-dev \ 
    curl \
    && rm -rf /var/lib/apt/lists/*

# Morse clone
RUN git clone --progress https://github.com/cangorur/morse.git -b 1.3.1_STABLE 


# We need python 3.5.3 specifically in order to match morse to blender
RUN apt-get update && apt-get install -y python3 python3-venv python3-dev

RUN apt-get update && apt-get install -y build-essential \
    checkinstall \
    libreadline-gplv2-dev \
    libncursesw5-dev \
    libssl-dev \
    libsqlite3-dev \
    tk-dev \
    libgdbm-dev \
    libc6-dev \
    libbz2-dev \
    zlib1g-dev \
    openssl \
    libffi-dev \
    python \
    python-pip \
    python3-dev\ 
    python3-pip \
    python3-setuptools \
    wget \
    blender \
    mesa-utils\
    && rm -rf /var/lib/apt/lists/*


# setup keys
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654

# setup sources.list
RUN echo "deb http://packages.ros.org/ros/ubuntu xenial main" > /etc/apt/sources.list.d/ros1-latest.list

# install bootstrap tools
RUN apt-get update && apt-get install --no-install-recommends -y \
    python-rosdep \
    python-rosinstall \
    python-vcstools \
    && rm -rf /var/lib/apt/lists/*

# setup environment
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# bootstrap rosdep
RUN rosdep init \
    && rosdep update

# install ros packages
ENV ROS_DISTRO kinetic
RUN apt-get update && apt-get install -y \
    ros-kinetic-ros-core=1.3.2-0* \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
    apt-get install -y nano \
    tmux wget git sudo libglu1\
    git xterm curl \
    && rm -rf /var/lib/apt/lists/*

# http://www.openrobots.org/morse/doc/1.3/user/installation/mw/ros.html

WORKDIR /

RUN wget http://pyyaml.org/download/pyyaml/PyYAML-3.10.tar.gz &&\
    tar xvf PyYAML-3.10.tar.gz &&\
    cd PyYAML-3.10 && \
    python3 setup.py install

RUN wget https://bootstrap.pypa.io/ez_setup.py &&\
    python3 ez_setup.py
RUN git clone https://github.com/ros/rospkg.git &&\
    cd rospkg &&\
    python3 setup.py install

RUN git clone https://github.com/ros-infrastructure/catkin_pkg.git \
    && cd catkin_pkg \
    && python3 setup.py install

RUN git clone https://github.com/ros/catkin.git \
    && cd catkin \
    && python3 setup.py install

ENV MORSE_BLENDER=/usr/bin/blender

RUN mkdir /morse/build

LABEL io.k8s.description="Headless VNC Container with Xfce window manager, firefox and chromium" \
      io.k8s.display-name="Headless VNC Container based on Ubuntu" \
      io.openshift.expose-services="6901:http,5901:xvnc" \
      io.openshift.tags="vnc, ubuntu, xfce" \
      io.openshift.non-scalable=true


## Connection ports for controlling the UI:
# VNC port:5901
# noVNC webport, connect via http://IP:6901/?password=vncpassword
ENV DISPLAY=:1 \
    VNC_PORT=5901 \
    NO_VNC_PORT=6901
EXPOSE $VNC_PORT $NO_VNC_PORT

### Envrionment config
ENV HOME=/headless \
    TERM=xterm \
    STARTUPDIR=/dockerstartup \
    INST_SCRIPTS=/headless/install \
    NO_VNC_HOME=/headless/noVNC \
    DEBIAN_FRONTEND=noninteractive \
    VNC_COL_DEPTH=24 \
    VNC_RESOLUTION=1920x1024 \
    VNC_PW=vncpassword \
    VNC_VIEW_ONLY=false
WORKDIR $HOME

### Add all install scripts for further steps
ADD ./vncsetup/src/common/install/ $INST_SCRIPTS/
ADD ./vncsetup/src/ubuntu/install/ $INST_SCRIPTS/
RUN find $INST_SCRIPTS -name '*.sh' -exec chmod a+x {} +

### Install some common tools
RUN $INST_SCRIPTS/tools.sh
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

### Install custom fonts
RUN $INST_SCRIPTS/install_custom_fonts.sh

### Install xvnc-server & noVNC - HTML5 based VNC viewer
RUN $INST_SCRIPTS/tigervnc.sh
RUN $INST_SCRIPTS/no_vnc.sh

#Install chrome
RUN $INST_SCRIPTS/chrome.sh

### Install xfce UI
RUN $INST_SCRIPTS/xfce_ui.sh
ADD ./vncsetup/src/common/xfce/ $HOME/

### Install VScode
RUN curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg && \
    install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/ && \
    sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'

RUN apt-get install -y apt-transport-https && \
    apt-get update && \
    apt-get install -y code\
    && rm -rf /var/lib/apt/lists/*

### configure startup
RUN $INST_SCRIPTS/libnss_wrapper.sh
ADD ./vncsetup/src/common/scripts $STARTUPDIR
RUN $INST_SCRIPTS/set_user_permission.sh $STARTUPDIR $HOME


WORKDIR /morse/build
RUN apt-get update &&  apt-get install -y python3-yaml\
    ros-kinetic-rviz \
    && rm -rf /var/lib/apt/lists/*

RUN cmake ..
RUN make install

RUN morse --noaudio check


WORKDIR /
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> ~/.bashrc
ENV MORSE_BLENDER=/usr/bin/blender
ENV MORSE_SILENT_PYTHON_CHECK=1
ENV NVIDIA_VISIBLE_DEVICES all


ENTRYPOINT ["/dockerstartup/vnc_startup.sh"]
CMD ["--wait"]

