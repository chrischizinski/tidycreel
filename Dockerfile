# Base image with ARM64 support and validated R version
FROM rocker/r-ver:4.4.0@sha256:4e32addfc4da3e660f6e0d05ce5e43d3eceb9db58a60b9a142e0dde9a654ead1

# Single validation check for R version compatibility
RUN R -e "if(getRversion() < '4.1.0') stop('R version requirement not met. DESCRIPTION requires R >=4.1.0')"

# System dependencies for R packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Create project directory
RUN mkdir -p /home/tidycreel
WORKDIR /home/tidycreel

# Install renv and restore packages
COPY renv.lock .
RUN Rscript -e 'install.packages("renv")' \
    && Rscript -e 'renv::restore()'

# Copy package files
COPY . .

# Install tidycreel
RUN R CMD INSTALL .

# Set default command
CMD ["R"]