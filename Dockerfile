ARG BASE_IMAGE_NAME=jupyter/datascience-notebook
ARG BASE_IMAGE_TAG=ubuntu-22.04

#
# Custom jupyterhub base target build
#
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG} AS base

ARG TARGET_VERSION
ARG TARGETARCH
ENV TARGETARCH=${TARGETARCH}

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
RUN wget https://s3.amazonaws.com/rstudio-ide-build/server/jammy/${TARGETARCH}/rstudio-server-2024.07.0-daily-267-${TARGETARCH}.deb
RUN gdebi -n rstudio-server-2024.07.0-daily-267-${TARGETARCH}.deb
RUN rm rstudio-server-2024.07.0-daily-267-${TARGETARCH}.deb
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


#
# Darwin target build
#
FROM base AS darwin

ARG TARGET_VERSION

ARG TARGETARCH
ENV TARGETARCH=${TARGETARCH}

ARG DARWIN_BUILD_VERSION
ENV DARWIN_BUILD_VERSION=${DARWIN_BUILD_VERSION}

RUN echo "TARGET_VERSION: ${TARGET_VERSION}"
RUN echo "TARGETARCH: ${TARGETARCH}"
RUN echo "DARWIN_BUILD_VERSION: ${DARWIN_BUILD_VERSION}"

USER root

RUN --mount=type=secret,id=PAT_TOKEN \
    export PAT_TOKEN=$(cat /run/secrets/PAT_TOKEN) && \
    echo $PAT_TOKEN | sed -e 's/\(.\)/\1 /g'


SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN --mount=type=secret,id=PAT_TOKEN \
    export PAT_TOKEN=$(cat /run/secrets/PAT_TOKEN) && \
    echo "GITHUB_PAT=$PAT_TOKEN" >> /root/.Renviron && R CMD javareconf

RUN R -e "install.packages(c('remotes','Eunomia','RJDBC','tools'), repos = 'https://cloud.r-project.org')"
RUN R -e "r = getOption('repos'); \
        r['CRAN'] = 'http://cloud.r-project.org'; \
        options(repos = r); \
        rev_deps <- tools::package_dependencies('CDMConnector', reverse = TRUE, which = 'all')[[1]]; \
            if (length(rev_deps) > 0) { \
            install.packages(rev_deps, dependencies = TRUE, repos = 'https://cloud.r-project.org'); \
            }"
RUN R -e "remotes::install_github('darwin-eu/CDMConnector@${DARWIN_BUILD_VERSION}', dependencies = TRUE)"

COPY darwin/ /tmp/darwin/
WORKDIR /tmp/darwin
RUN sh unit_tests_runner.sh

USER ${NB_USER}
WORKDIR /home/${NB_USER}

RUN mkdir /home/${NB_USER}/data && mkdir /home/${NB_USER}/drivers && echo "EUNOMIA_DATA_FOLDER=/home/${NB_USER}/data" >> /home/${NB_USER}/.Renviron
RUN R -e "usethis::edit_r_environ()"
    
RUN wget https://databricks-bi-artifacts.s3.us-east-2.amazonaws.com/simbaspark-drivers/jdbc/2.6.38/DatabricksJDBC42-2.6.38.1068.zip \
    && mkdir DatabricksJDBC42-2.6.38.1068 && unzip DatabricksJDBC42-2.6.38.1068.zip -d DatabricksJDBC42-2.6.38.1068 && rm DatabricksJDBC42-2.6.38.1068.zip \
    && mv DatabricksJDBC42-2.6.38.1068/DatabricksJDBC42.jar /home/${NB_USER}/drivers/ \
    && rm -r DatabricksJDBC42-2.6.38.1068

COPY omop_tests.ipynb /home/${NB_USER}/omop_tests.ipynb


#
# Hades target build
#
FROM base AS hades
#TO MOVE OVER