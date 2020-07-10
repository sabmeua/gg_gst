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
    yum install -y gstreamer1 gstreamer1-devel gstreamer1-plugins-base \
    gstreamer1-plugins-base-devel gstreamer1-plugins-bad-free \
    gstreamer1-plugins-bad-free-devel gstreamer1-plugins-good \
    gstreamer1-plugins-base-tools gstreamer1-plugins-bad-free-gtk \
    gstreamer1-plugins-ugly-free gstreamer1-plugins-ugly-free-devel \
    python3-devel pycairo pycairo-devel pygobject3-devel cairo-gobject-devel \
    wget bzip2-devel orc-devel && \
    yum group install -y Development tools && \
    rm -rf /var/cache/yum

RUN git clone https://github.com/GStreamer/gst-python.git
WORKDIR gst-python
RUN git fetch --tag
RUN git checkout `gst-launch-1.0 --version | head -n1 | awk '{print $NF}'`
ENV PYTHON=/usr/bin/python3
RUN ./autogen.sh --disable-gtk-doc
RUN make -j8 && make install

WORKDIR /

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

# libx264 must be older than ver.0.152
#RUN git clone https://github.com/mirror/x264.git
#WORKDIR x264
#RUN git fetch origin stable
#RUN git checkout stable
RUN wget ftp://ftp.videolan.org/pub/x264/snapshots/x264-snapshot-20180801-2245-stable.tar.bz2
RUN tar xf x264-snapshot-20180801-2245-stable.tar.bz2
WORKDIR x264-snapshot-20180801-2245-stable
RUN ./configure --enable-static --enable-shared
RUN make -j8 && make install
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
RUN ldconfig /usr/local/lib

WORKDIR /

RUN wget https://gstreamer.freedesktop.org/src/gst-plugins-ugly/gst-plugins-ugly-`gst-launch-1.0 --version | head -n1 | awk '{print $NF}'`.tar.xz
RUN tar xf ./gst-plugins-ugly-`gst-launch-1.0 --version | head -n1 | awk '{print $NF}'`.tar.xz
RUN ln -s ./gst-plugins-ugly-`gst-launch-1.0 --version | head -n1 | awk '{print $NF}'` ./gst-plugins-ugly
WORKDIR gst-plugins-ugly
RUN ./configure --enable-x264 --enable-orc
RUN make -j8 && make install

WORKDIR /

RUN wget https://gstreamer.freedesktop.org/src/gst-libav/gst-libav-`gst-launch-1.0 --version | head -n1 | awk '{print $NF}'`.tar.xz
RUN tar xf ./gst-libav-`gst-launch-1.0 --version | head -n1 | awk '{print $NF}'`.tar.xz
RUN ln -s ./gst-libav-`gst-launch-1.0 --version | head -n1 | awk '{print $NF}'` ./gst-libav
WORKDIR gst-libav
#RUN ./configure --with-libav-extra-configure="--enable-libx264 --enable-gpl" --enable-gpl --enable-orc
RUN ./configure --enable-gpl --enable-orc
RUN make -j8 && make install

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
RUN cp ./*.so /usr/local/lib/gstreamer-1.0

WORKDIR /

RUN pip3 install PyGObject numpy==1.16.4 opencv-python
RUN pip3 install tensorflow==1.14 trafaret greengrasssdk
RUN pip3 install git+https://github.com/jackersson/gstreamer-python.git#egg=gstreamer-python

ENV GST_PLUGIN_PATH=/usr/local/lib/gstreamer-1.0:/myplugins
ENV GST_DEBUG=python:4

COPY kvs_log_configuration .
COPY myplugins .

#RUN pip3 install Cython contextlib2 pillow lxml matplotlib tf_slim
#RUN git clone https://github.com/tensorflow/models.git
#RUN pip3 install pycocotools scipy
#RUN wget https://github.com/google/protobuf/releases/download/v3.3.0/protoc-3.3.0-linux-x86_64.zip
#RUN unzip -d /usr protoc-3.3.0-linux-x86_64.zip
#WORKDIR models/research
#RUN protoc object_detection/protos/*.proto --python_out=.
#ENV PYTHONPATH=$PYTHONPATH:/models/research/object_detection:/models/research/slim
## test object detection api
#RUN python3 object_detection/builders/model_builder_tf1_test.py
