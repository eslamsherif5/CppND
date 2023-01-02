FROM ubuntu:18.04 as builder

# =============================================== #
#               ADD A NEW SUDO USER               #
# =============================================== #

ENV USERNAME cppnd
ENV HOME /home/$USERNAME

# Add a user named $USERNAME and create its home directory (-m)
# # RUN useradd -m $USERNAME && \

# set the new user's password as username:password using chpasswd
# # echo "$USERNAME:$USERNAME" | chpasswd && \

# Modify the user $USERNAME to select a login shell for this user as /bin/bash
# # usermod --shell /bin/bash $USERNAME && \

# Modify the user $USERNAME to append (-a) it to the group (-G) sudo
# # usermod -aG sudo $USERNAME && \

# Make a new directory /etc/sudoers.d
# # mkdir /etc/sudoers.d && \

# Adding user account to sudoers
# # echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME && \

# Set permissions for the new user
# # chmod 0440 /etc/sudoers.d/$USERNAME && \

# Set the user/group id for the new user
# # Replace 1000 with your user/group id
# # usermod  --uid 1000 $USERNAME && \
# # groupmod --gid 1000 $USERNAME

RUN useradd -m $USERNAME && \
        echo "$USERNAME:$USERNAME" | chpasswd && \
        usermod --shell /bin/bash $USERNAME && \
        usermod -aG sudo $USERNAME && \
        mkdir /etc/sudoers.d && \
        echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME && \
        chmod 0440 /etc/sudoers.d/$USERNAME && \
        # Replace 1000 with your user/group id
        usermod  --uid 1001 $USERNAME && \
        groupmod --gid 1001 $USERNAME


# =============================================== #
#           INSTALL ESSENTIAL PACKAGES            #
# =============================================== #

RUN echo "Acquire::GzipIndexes \"false\"; Acquire::CompressionTypes::Order:: \"gz\";" > /etc/apt/apt.conf.d/docker-gzip-indexes
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && TZ=Etc/UTC apt-get install -y --no-install-recommends \
        build-essential \
        sudo \
        less \
        apt-utils \
        tzdata \
        git \
        tmux \
        bash-completion \
        command-not-found \
        software-properties-common \
        curl \
        wget\
        gnupg2 \
        lsb-release \
        keyboard-configuration \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*


# =============================================== #
#              INSTALL libGL & FRIENDS            #
# =============================================== #

RUN apt-get update \
    && apt-get install -y \
        libssl-dev \
        libgl1-mesa-dev

# ============================================= #
#                INSTALL CMake                  #
# ============================================= #

WORKDIR /tmp
ENV CMAKE_VERSION="3.11.3"
RUN wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz \
    && tar -xvf cmake-${CMAKE_VERSION}.tar.gz \
    && cd cmake-${CMAKE_VERSION} \
    && ./bootstrap -- -DCMAKE_BUILD_TYPE:STRING=Release \
    && make \
    && make install

# ============================================= #
#                 INSTALL VTK                   #
# ============================================= #

WORKDIR /tmp
RUN apt-get update && apt-get install -y \
    libxt-dev zlib1g-dev libpng-dev
RUN wget https://www.vtk.org/files/release/8.2/VTK-8.2.0.tar.gz \
    && tar -xf VTK-8.2.0.tar.gz \
    && cd VTK-8.2.0 && mkdir build && cd build \
    && cmake .. -DVTK_MODULE_ENABLE_VTK_RenderingContextOpenGL2=YES \
                -DCMAKE_BUILD_TYPE=Release -DVTK_USE_SYSTEM_PNG=ON \
    && make -j$(nproc) \
    && make install


# ========================================= #
#               POST-BUILD                  #
# ========================================= #

    # ======== Install sublime text ==========
RUN wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
RUN sudo apt-get install apt-transport-https
RUN echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list
RUN DEBIAN_FRONTEND=noninteractive apt-get update  -y\
    && DEBIAN_FRONTEND=noninteractive sudo apt-get install sublime-text -y

    # ======= Installing basic pkgs/tools
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && apt-get install -y \
    terminator \
    dbus \
    dbus-x11 \
    gdb \
    rsync \
    nano \
    psmisc \
    inetutils-inetd \
    inetutils-ping

# ====================================== #
#          ADD A NEW LAYER HERE          #
# ====================================== #



# ===================================== #
#       Cleaning up the messsssss       #
# ===================================== #

WORKDIR /home/$USERNAME
RUN rm -rf /tmp/ && mkdir /tmp && chmod 1777 /tmp

    # ======== Config ssh ============
RUN apt-get install -y openssh-server
RUN ssh-keygen -A

    # ============ Configure apt-get autocompletion ============ #
RUN rm /etc/apt/apt.conf.d/docker-clean \
    && touch /etc/apt/apt.conf.d/docker-clean \
    && echo "DPkg::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };" > /etc/apt/apt.conf.d/docker-clean

# ==================================================== #
#            LOGIN USING THE USER $USERNAME            #
# ==================================================== #

USER $USERNAME 
WORKDIR /home/$USERNAME

# ========== Add environment variables to .bashrc ==========
# COPY bashrc_update .
# RUN cat bashrc_update >> ~/.bashrc \

RUN sudo apt-get update

RUN mkdir /home/$USERNAME/workspace \
    && chgrp $USERNAME /home/$USERNAME/workspace \
    && chown $USERNAME /home/$USERNAME/workspace
# COPY super_client_configuration_file.xml .
# ENV FASTRTPS_DEFAULT_PROFILES_FILE=/home/$USERNAME/workspace/super_client_configuration_file.xml

# ====================================== #
#          INSTALL IO2D LIBRARY          #
# ====================================== #

WORKDIR /home/$USERNAME/workspace
RUN DEBIAN_FRONTEND=noninteractive sudo apt-get update \
    && sudo apt-get install -y \
    libboost-all-dev \
    libcairo2-dev \
    libgraphicsmagick1-dev \
    libpng-dev

RUN git clone --recurse-submodules https://github.com/cpp-io2d/P0267_RefImpl \
    && cd P0267_RefImpl \
    && mkdir Debug && cd Debug \
    && cmake --config Debug "-DCMAKE_BUILD_TYPE=Debug" .. \
    && cmake --build . \
    && sudo make install

# =============================================== #
#          COMPILE ROUTE PLANNING PROJECT         #
# =============================================== #

WORKDIR /home/$USERNAME/workspace

RUN git clone https://github.com/udacity/CppND-Route-Planning-Project.git --recurse-submodules \
    && cd CppND-Route-Planning-Project \
    && mkdir build && cd build \
    && cmake .. \
    && make

# ====================================== #
#          ADD A NEW LAYER HERE          #
# ====================================== #




# =========================================== #
#          ADD ENTRYPOINT & FINALIZE          #
# =========================================== #

WORKDIR /home/$USERNAME
COPY entrypoint.sh .
RUN sudo chmod +x entrypoint.sh
ENTRYPOINT ["./entrypoint.sh"]
