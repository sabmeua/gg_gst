FROM ubuntu:18.04

RUN apt update && apt upgrade -y
RUN apt install -y --no-install-recommends \
    build-essential git curl wget \
    python3 python3.6 python3.6-dev python3.6-distutils python3-pip python3-venv python3.6-venv \
    sudo vim pkg-config cmake autoconf automake libtool \
    gstreamer-1.0 gstreamer1.0-dev libgstreamer1.0-0 gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav gstreamer1.0-doc gstreamer1.0-tools gstreamer1.0-x gstreamer1.0-alsa \
    gstreamer1.0-gl gstreamer1.0-gtk3 gstreamer1.0-qt5 gstreamer1.0-pulseaudio \
    python-gst-1.0 libgirepository1.0-dev libgstreamer-plugins-base1.0-dev \
    libcairo2-dev gir1.2-gstreamer-1.0 python3-gi python-gi-dev python3-keras
RUN git clone https://github.com/jackersson/gst-plugins-tf.git
WORKDIR gst-plugins-tf
RUN python3 -m venv venv
RUN . venv/bin/activate && pip install --upgrade wheel pip setuptools
RUN . venv/bin/activate && pip install --upgrade -r requirements.txt
RUN . venv/bin/activate && pip install tensorflow==1.15
RUN wget https://github.com/iterative/dvc/releases/download/0.94.0/dvc_0.94.0_amd64.deb
RUN dpkg -i dvc_0.94.0_amd64.deb
ENV GOOGLE_APPLICATION_CREDENTIALS=/gst-plugins-tf/credentials/gs_viewer.json
RUN dvc pull
RUN rm dvc_0.94.0_amd64.deb
