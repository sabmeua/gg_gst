FROM amazonlinux:2

# Set ENV_VAR for Greengrass RC to be untarred inside Docker Image
ARG GREENGRASS_RELEASE_URL=https://d1onfpft10uf5o.cloudfront.net/greengrass-core/downloads/1.10.2/greengrass-linux-x86-64-1.10.2.tar.gz

# Install Greengrass Core Dependencies
RUN yum update -y && \
    yum install -y shadow-utils tar.x86_64 gzip xz wget iproute java-1.8.0 make && \
    yum install -y openssl-devel python27 python37 && \
    ln -s /usr/bin/java /usr/local/bin/java8 && \
    wget $GREENGRASS_RELEASE_URL && \
    wget https://nodejs.org/dist/v6.10.2/node-v6.10.2-linux-x64.tar.xz && \
    tar xf node-v6.10.2-linux-x64.tar.xz && \
    cp node-v6.10.2-linux-x64/bin/node /usr/bin/nodejs6.10 && \
    wget https://nodejs.org/dist/v8.10.0/node-v8.10.0-linux-x64.tar.xz && \
    tar xf node-v8.10.0-linux-x64.tar.xz && \
    cp node-v8.10.0-linux-x64/bin/node /usr/bin/nodejs8.10 && \
    wget https://nodejs.org/dist/v12.13.0/node-v12.13.0-linux-x64.tar.xz && \
    tar xf node-v12.13.0-linux-x64.tar.xz && \
    cp node-v12.13.0-linux-x64/bin/node /usr/bin/nodejs12.x && \
    ln -s /usr/bin/nodejs12.x /usr/bin/node && \
    rm -rf node-v6.10.2-linux-x64.tar.xz node-v6.10.2-linux-x64 && \
    rm -rf node-v8.10.0-linux-x64.tar.xz node-v8.10.0-linux-x64 && \
    rm -rf node-v12.13.0-linux-x64 node-v12.13.0-linux-x64.tar.xz && \
    yum remove -y wget && \
    rm -rf /var/cache/yum

# Copy Greengrass Licenses AWS IoT Greengrass Docker Image
COPY greengrass-license-v1.pdf /

# Copy start-up script
COPY "greengrass-entrypoint.sh" /

# Setup Greengrass inside Docker Image
RUN export GREENGRASS_RELEASE=$(basename $GREENGRASS_RELEASE_URL) && \
    tar xzf $GREENGRASS_RELEASE -C / && \
    rm $GREENGRASS_RELEASE && \
    useradd -r ggc_user && \
    groupadd -r ggc_group

# Expose 8883 to pub/sub MQTT messages
EXPOSE 8883

RUN ln -s /lib/python2.7/site-packages/amazon_linux_extras /lib/python3.7/site-packages/

RUN yum update -y && \
    yum install -y python3-devel pycairo pycairo-devel pygobject3-devel cairo-gobject-devel \
    wget bzip2-devel orc-devel libsoup libsoup-devel && \
    yum group install -y Development tools && \
    rm -rf /var/cache/yum

RUN pip3 install meson ninja install PyGObject numpy==1.16.4 opencv-python tensorflow==1.14 greengrasssdk

RUN curl -O -L https://www.nasm.us/pub/nasm/releasebuilds/2.14.02/nasm-2.14.02.tar.bz2
RUN tar xf nasm-2.14.02.tar.bz2
WORKDIR nasm-2.14.02
RUN ./autogen.sh
RUN ./configure
RUN make -j8 && make install

WORKDIR /

RUN curl -O -L https://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz
RUN tar xf yasm-1.3.0.tar.gz
WORKDIR yasm-1.3.0
RUN ./configure
RUN make -j8 && make install

WORKDIR /

RUN git clone https://gitlab.freedesktop.org/gstreamer/gst-build.git
WORKDIR gst-build
RUN meson --prefix=/usr build
RUN (cd build; ninja; ninja install)

WORKDIR /

RUN wget https://github.com/Kitware/CMake/releases/download/v3.17.3/cmake-3.17.3-Linux-x86_64.sh
RUN chmod +x cmake-3.17.3-Linux-x86_64.sh
RUN ./cmake-3.17.3-Linux-x86_64.sh --skip-license --prefix=/usr

RUN git clone --recursive https://github.com/awslabs/amazon-kinesis-video-streams-producer-sdk-cpp.git
WORKDIR amazon-kinesis-video-streams-producer-sdk-cpp
RUN mkdir -p build
WORKDIR build
RUN cmake -DBUILD_GSTREAMER_PLUGIN=ON ..
RUN make -j8
RUN cp ./*.so /usr/lib64/gstreamer-1.0

WORKDIR /

RUN pip3 install git+https://github.com/jackersson/gstreamer-python.git#egg=gstreamer-python

RUN yum update -y && \
    yum install -y mesa-dri-drivers mesa-filesystem mesa-libEGL mesa-libGL mesa-libGLES \
    mesa-libGLU mesa-libOSMesa mesa-libgbm mesa-libglapi mesa-libwayland-egl \
    mesa-libxatracker mesa-vdpau-drivers mesa-vulkan-drivers mesa-libGLw && \
    rm -rf /var/cache/yum

ENV GST_PLUGIN_PATH=/myplugins
ENV GST_DEBUG=python:4

COPY kvs_log_configuration .
COPY myplugins .
