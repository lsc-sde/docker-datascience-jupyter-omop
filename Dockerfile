ARG BASE_IMAGE_NAME=jupyter/datascience-notebook
ARG BASE_IMAGE_TAG=ubuntu-22.04
ARG BASE_PLATFORM=arm64

FROM --platform=linux/${BASE_PLATFORM} ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

ARG PLATFORM=arm64
ARG TARGET_IMAGE_NAME=datascience-notebook-omop
ARG TARGET_IMAGE_TAG=darwin
ARG DARWIN_BUILD=false
ARG DARWIN_PACKAGE=darwin-eu/CDMConnector
ARG DARWIN_VERSION=v1.3.1
ARG PAT_TOKEN=xyz

LABEL image=${TARGET_IMAGE_NAME}

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
 tigervnc-xorg-extension

RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*


# RStudio Server
RUN wget https://s3.amazonaws.com/rstudio-ide-build/server/jammy/${PLATFORM}/rstudio-server-2024.07.0-daily-267-${PLATFORM}.deb
RUN gdebi -n rstudio-server-2024.07.0-daily-267-${PLATFORM}.deb
RUN rm rstudio-server-2024.07.0-daily-267-${PLATFORM}.deb
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

# Install OMOP R Packages
RUN R -e "install.packages('remotes',dependencies=TRUE, repos='https://cloud.r-project.org/')" && \
    if ["${DARWIN_BUILD}" = "true"] ; then \
    R -e "remotes::install_github('${DARWIN_PACKAGE}@${DARWIN_VERSION}')" ; else echo "Ignore DARWIN OMOP support" ; fi ;


#&& \
#R -e "remotes::install_github('ohdsi/Hades')"

USER ${NB_UID}
