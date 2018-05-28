## GPU enabled nvidia-docker base image

## BUILD ARGUMENTS - Fine Tune CUDA Build Image Here##
ARG cudaTKversion=9.0
ARG    cuDNNversion=7

FROM nvidia/cuda:${cudaTKversion}-cudnn${cuDNNversion}-runtime

LABEL   maintainer='Dima Karpa dimakarpa.com'

LABEL   description="This 5GB image is based heavily off of Jupyter's Notebook Stacks with \
2 important changes.  It uses Nvidia CUDA and cuDNN for tensorflow support and it installs Anaconda \
rather than Miniconda, hence the larger image size.  Many of the environmentals used in Jupyter \
Notebook Stacks can be used with this image.  Thanks Jupyter!"

LABEL   IMPORTANT='As of May 2018, the image uses CUDA Toolkit 9.0 for TensorFlow support.  \
In order to run anything but 9.0, you must compile your own binaries which takes hours.  When \
TensorFlow includes a pip install for later toolkits, simply change the base image "9.0" to whatever\
version is required.'

## Use Root to install required installation packages
USER root

ENV DEBIAN_FRONTEND noninteractive

## Install necessary packages to install Miniconda
RUN apt-get update && \
        apt-get -yq dist-upgrade && \
        apt-get install -yq --no-install-recommends \
        curl \
        wget \
        ca-certificates \
        vim \
        bzip2 \
        sudo \
        nano \
        zsh \
        git \
        locales \
        python-dev \
        build-essential \
        cuda-command-line-tools-9-2 && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/*

## Add American-English to locale.gen
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
        locale-gen

# Install Tini
RUN wget --quiet https://github.com/krallin/tini/releases/download/v0.18.0/tini && \
    mv tini /usr/local/bin/tini && \
    chmod +x /usr/local/bin/tini

# Configure environment
ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash \
    NB_USER=jovyan \
    NB_UID=1000 \
    NB_GID=100 \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8
ENV PATH=$CONDA_DIR/bin:$PATH \
    HOME=/home/$NB_USER

ADD fix-permissions /usr/local/bin/fix-permissions
# Create jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    mkdir -p $CONDA_DIR && \
    chown $NB_USER:$NB_GID $CONDA_DIR && \
    chmod g+w /etc/passwd /etc/group && \
    fix-permissions $HOME && \
    fix-permissions $CONDA_DIR

USER $NB_UID

# Setup work directory for backward-compatibility
RUN mkdir /home/$NB_USER/work && \
    fix-permissions /home/$NB_USER

# Install anaconda for latest python environment
ENV     CONDA_VERSION=Anaconda3-5.1.0

RUN     cd /tmp && \
        curl -o anaconda.sh \
        https://repo.continuum.io/archive/${CONDA_VERSION}-Linux-x86_64.sh && \
        bash anaconda.sh -f -b -p $CONDA_DIR && \
        rm anaconda.sh  && \
        $CONDA_DIR/bin/conda config --system --prepend channels conda-forge && \
        $CONDA_DIR/bin/conda config --system --set auto_update_conda false && \
        $CONDA_DIR/bin/conda config --system --set show_channel_urls true && \
        $CONDA_DIR/bin/conda update --all --quiet --yes && \
        conda clean -tipsy && \
        rm -rf /home/$NB_USER/.cache/yarn && \
        fix-permissions $CONDA_DIR && \
        fix-permissions /home/$NB_USER

RUN jupyter notebook --generate-config

# Create ENV for cudaTKversion
ENV CTKversion=

## Add CUDA folders to PATH
RUN echo 'export PATH=/usr/local/cuda-9.0/bin${PATH:+:${PATH}}' >> ~/.bashrc
RUN echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda-9.0/lib64' >> ~/.bashrc
Run echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/extras/CUPTI/lib64' >> ~/.bashrc

USER root

EXPOSE 8888

WORKDIR $HOME

# Configure container startup
ENTRYPOINT ["tini", "--"]
CMD ["start-notebook.sh"]

# Add local files as late as possible to avoid cache busting
COPY start.sh /usr/local/bin/
COPY start-notebook.sh /usr/local/bin/
COPY start-singleuser.sh /usr/local/bin/
COPY jupyter_notebook_config.py /etc/jupyter/
RUN fix-permissions /home/$NB_USER/

# Switch back to jovyan to avoid accidental container runs as root
USER $NB_UID
