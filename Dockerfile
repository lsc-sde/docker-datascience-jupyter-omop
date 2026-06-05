FROM quay.io/jupyter/datascience-notebook:ubuntu-24.04 AS jupyter_ds_base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

ARG RSTUDIO_VERSION
ENV RSTUDIO_VERSION=${RSTUDIO_VERSION}
ARG TARGETARCH
ENV TARGETARCH=${TARGETARCH}

# RUN echo "${NB_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${NB_USER}

RUN apt-get update && apt-get install -y --no-install-recommends \
        default-jdk \
        gdebi-core \
        libssl-dev \
        psmisc \
        libclang-dev \
        lsb-release \
        wget && \
    rm -rf /var/lib/apt/lists/*

# Install RStudio Server
RUN wget https://s3.amazonaws.com/rstudio-ide-build/server/jammy/${TARGETARCH}/rstudio-server-${RSTUDIO_VERSION}-${TARGETARCH}.deb && \
    gdebi -n rstudio-server-${RSTUDIO_VERSION}-${TARGETARCH}.deb && \
    rm rstudio-server-${RSTUDIO_VERSION}-${TARGETARCH}.deb && \
    echo "server-user=${NB_USER}" >> /etc/rstudio/rserver.conf && \
    echo "rsession-which-r=${CONDA_DIR}/bin/R" >> /etc/rstudio/rserver.conf && \
    echo "rsession-ld-library-path=${CONDA_DIR}/lib" >> /etc/rstudio/rserver.conf && \
    chown -R ${NB_USER} /var/lib/rstudio-server /etc/rstudio

ENV PATH=$PATH:/usr/lib/rstudio-server/bin \
    R_HOME=/opt/conda/lib/R

COPY environment.yaml environment.yaml

RUN mamba env update --name base --file environment.yaml \
    && rm environment.yaml \
    && mamba clean --all -f -y \
    && fix-permissions "${CONDA_DIR}" \
    && fix-permissions "/home/${NB_USER}"

USER ${NB_UID}
WORKDIR /home/${NB_USER}


FROM jupyter_ds_base AS darwin_core

ARG DARWIN_BUILD_VERSION
ENV DARWIN_BUILD_VERSION=${DARWIN_BUILD_VERSION}

ARG EXTRA_PACKAGES=""
ENV EXTRA_PACKAGES=${EXTRA_PACKAGES}

USER root

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Force conda to use system compiler to avoid system and conda compiler mismatch
COPY Makevars.site /opt/conda/lib/R/etc/Makevars.site

RUN --mount=type=secret,id=PAT_TOKEN \
    export GITHUB_PAT=$(cat /run/secrets/PAT_TOKEN) && \
    echo "GITHUB_PAT=$GITHUB_PAT" >> /root/.Renviron && R CMD javareconf && \
    R_LIBS_USER="" R -e "install.packages('pak', repos = 'https://cloud.r-project.org', type = 'source')" && \
    R_LIBS_USER="" R -e "pak::pkg_install(c('parallel', 'git2r', 'Eunomia', 'RJDBC', 'tools', 'RPostgres', 'rsvg', 'darwin-eu/CDMConnector@${DARWIN_BUILD_VERSION}'), dependencies = TRUE)" && \
    if [ -n "${EXTRA_PACKAGES}" ]; then R_LIBS_USER="" R -e "pak::pkg_install(strsplit('${EXTRA_PACKAGES}', ',')[[1]], dependencies = TRUE)"; fi

USER ${NB_USER}
WORKDIR /home/${NB_USER}