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
RUN apt-get update -y && apt-get install -y --no-install-recommends \
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
 unzip \
 odbcinst1debian2 \
 libodbc1 \
 odbcinst \
 unixodbc \
 libsasl2-modules-gssapi-mit \
 libgit2-dev \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# ODBC driver & RStudio Server
RUN wget https://databricks-bi-artifacts.s3.us-east-2.amazonaws.com/simbaspark-drivers/odbc/2.8.2/SimbaSparkODBC-2.8.2.1013-Debian-64bit.zip \
        && unzip SimbaSparkODBC-2.8.2.1013-Debian-64bit.zip \
        && apt install ./simbaspark_2.8.2.1013-2_amd64.deb \
        && rm *.* && \
    wget https://s3.amazonaws.com/rstudio-ide-build/server/jammy/${TARGETARCH}/rstudio-server-2024.07.0-daily-267-${TARGETARCH}.deb \
    && gdebi -n rstudio-server-2024.07.0-daily-267-${TARGETARCH}.deb \
    && rm rstudio-server-2024.07.0-daily-267-${TARGETARCH}.deb \
    && echo server-user=${NB_USER} >> /etc/rstudio/rserver.conf

ENV PATH=$PATH:/usr/lib/rstudio-server/bin
ENV RSESSION_PROXY_RSTUDIO_1_4=True

COPY environment.yaml environment.yaml

# Python libs for XFCE/VNC R proxy
RUN mamba env update --name base --file environment.yaml \
    && rm environment.yaml \
    && mamba clean --all -f -y \
    && fix-permissions "${CONDA_DIR}" \
    && fix-permissions "/home/${NB_USER}"

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

#RUN echo "TARGET_VERSION: ${TARGET_VERSION}"
#RUN echo "TARGETARCH: ${TARGETARCH}"
#RUN echo "DARWIN_BUILD_VERSION: ${DARWIN_BUILD_VERSION}"

USER root

RUN --mount=type=secret,id=PAT_TOKEN \
    export PAT_TOKEN=$(cat /run/secrets/PAT_TOKEN) && \
    echo $PAT_TOKEN | sed -e 's/\(.\)/\1 /g'


SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN --mount=type=secret,id=PAT_TOKEN \
    export PAT_TOKEN=$(cat /run/secrets/PAT_TOKEN) && \
    echo "GITHUB_PAT=$PAT_TOKEN" >> /root/.Renviron && R CMD javareconf

RUN R -e "install.packages(c('parallel', 'git2r'), repos = 'https://cloud.r-project.org', Ncpus = 4 )" \
    && R -e "install.packages(c('remotes','Eunomia','RJDBC','tools'), repos = 'https://cloud.r-project.org', Ncpus = parallel::detectCores() )" \
    && R -e "r = getOption('repos'); \
        r['CRAN'] = 'http://cloud.r-project.org'; \
        options(repos = r); \
        rev_deps <- tools::package_dependencies('CDMConnector', reverse = TRUE, which = 'all')[[1]]; \
            if (length(rev_deps) > 0) { \
            install.packages(rev_deps, dependencies = TRUE, repos = 'https://cloud.r-project.org', Ncpus = parallel::detectCores() ); \
            }" \
    && R -e "remotes::install_github('darwin-eu/CDMConnector@${DARWIN_BUILD_VERSION}', auth_token = Sys.getenv('PAT_TOKEN'), dependencies = TRUE, Ncpus = parallel::detectCores() )"

COPY darwin/ /tmp/darwin/
WORKDIR /tmp/darwin
RUN sh unit_tests_runner.sh

USER ${NB_USER}
WORKDIR /home/${NB_USER}

RUN mkdir /home/${NB_USER}/data && mkdir /home/${NB_USER}/drivers && echo "EUNOMIA_DATA_FOLDER=/home/${NB_USER}/data" >> /home/${NB_USER}/.Renviron \
    && R -e "usethis::edit_r_environ()" \
    && wget https://databricks-bi-artifacts.s3.us-east-2.amazonaws.com/simbaspark-drivers/jdbc/2.6.38/DatabricksJDBC42-2.6.38.1068.zip \
    && mkdir DatabricksJDBC42-2.6.38.1068 && unzip DatabricksJDBC42-2.6.38.1068.zip -d DatabricksJDBC42-2.6.38.1068 && rm DatabricksJDBC42-2.6.38.1068.zip \
    && mv DatabricksJDBC42-2.6.38.1068/DatabricksJDBC42.jar /home/${NB_USER}/drivers/ \
    && rm -r DatabricksJDBC42-2.6.38.1068

COPY omop_tests.ipynb /home/${NB_USER}/omop_tests.ipynb

#
# Hades target build
#
FROM base AS hades

ARG TARGET_VERSION

ARG TARGETARCH
ENV TARGETARCH=${TARGETARCH}

ARG HADES_BUILD_VERSION
ENV HADES_BUILD_VERSION=${HADES_BUILD_VERSION}

RUN echo "TARGET_VERSION: ${TARGET_VERSION}"
RUN echo "TARGETARCH: ${TARGETARCH}"
RUN echo "HADES_BUILD_VERSION: ${HADES_BUILD_VERSION}"

USER root

RUN --mount=type=secret,id=PAT_TOKEN \
    export PAT_TOKEN=$(cat /run/secrets/PAT_TOKEN) && \
    echo $PAT_TOKEN | sed -e 's/\(.\)/\1 /g'

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN --mount=type=secret,id=PAT_TOKEN \
    export PAT_TOKEN=$(cat /run/secrets/PAT_TOKEN) && \
    echo "GITHUB_PAT=$PAT_TOKEN" >> /root/.Renviron && R CMD javareconf

RUN R -e "install.packages(c('parallel', 'git2r'), repos = 'https://cloud.r-project.org', Ncpus = 4 )" && \
    R -e "install.packages(c('remotes','Eunomia','RJDBC','tools'), repos='https://cloud.r-project.org/', Ncpus = parallel::detectCores() )" && \
    R -e "remotes::install_github('ohdsi/Hades@${HADES_BUILD_VERSION}', auth_token = Sys.getenv('PAT_TOKEN'), dependencies = TRUE, build_vignettes = FALSE, , Ncpus = parallel::detectCores() )"

USER ${NB_USER}