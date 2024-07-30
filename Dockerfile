ARG BASE_IMAGE_NAME=jupyter/datascience-notebook
ARG BASE_IMAGE_TAG=ubuntu-22.04

FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

ARG VARIANT
ARG VERSION

ARG BUILDARCH
ENV BUILDARCH=${BUILDARCH}


SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root
RUN apt-get update -y
#RUN apt-get upgrade -y
RUN apt-get install -y --no-install-recommends \
 lsb-release \
 psmisc \
 libssl-dev \
 gdebi-core \
 libclang-dev \
 dbus-x11 \
 xfce4 \
 xfce4-panel \
 xfce4-session \
 xfce4-settings \
 xorg \
 xubuntu-icon-theme \
 tigervnc-standalone-server \
 tigervnc-xorg-extension \
 default-jdk \
 default-jre \
 unzip

RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*


# RStudio Server
RUN wget https://s3.amazonaws.com/rstudio-ide-build/server/jammy/${BUILDARCH}/rstudio-server-2024.07.0-daily-267-${BUILDARCH}.deb
RUN gdebi -n rstudio-server-2024.07.0-daily-267-${BUILDARCH}.deb
RUN rm rstudio-server-2024.07.0-daily-267-${BUILDARCH}.deb
RUN echo server-user=${NB_USER} >> /etc/rstudio/rserver.conf
ENV PATH=$PATH:/usr/lib/rstudio-server/bin
ENV RSESSION_PROXY_RSTUDIO_1_4=True

COPY environment.yaml environment.yaml

# Python libs for XFCE/VNC R proxy
RUN mamba env update --name base --file environment.yaml
RUN rm environment.yaml
RUN mamba clean --all -f -y
RUN fix-permissions "${CONDA_DIR}"
RUN fix-permissions "/home/${NB_USER}"


USER ${NB_USER}