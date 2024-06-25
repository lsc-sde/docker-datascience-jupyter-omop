# LSCSDE maintained analytics workspace image with integrated OHDSI Methods library (i.e. Hades) 

ARG OWNER=lscsde
ARG BASE_CONTAINER=lscsde/datascience-notebook-default:0.1.19
FROM $BASE_CONTAINER
ARG TARGETOS TARGETARCH
LABEL maintainer="lscsde"
LABEL image="datascience-notebook-hades"

# Fix: https://github.com/hadolint/hadolint/wiki/DL4006
# Fix: https://github.com/koalaman/shellcheck/wiki/SC3014
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

#
# TODO
#

# Switch back to jovyan
USER ${NB_UID}
