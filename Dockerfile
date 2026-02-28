# syntax=docker/dockerfile:1.5
# Base image tracking the current R release (matches GH Actions "release")
FROM rocker/r-ver:latest AS base

# Single validation check for R version compatibility
RUN R -e "if(getRversion() < '4.1.0') stop('R version requirement not met. DESCRIPTION requires R >=4.1.0')"

# Align build-time environment with GH Actions
ENV DEBIAN_FRONTEND=noninteractive \
    _R_CHECK_FORCE_SUGGESTS_=false \
    _R_CHECK_CRAN_INCOMING_REMOTE_=false \
    R_DEFAULT_INTERNET_TIMEOUT=20 \
    LC_ALL=C.UTF-8 \
    XDG_CACHE_HOME=/root/.cache \
    PAK_CACHE_DIR=/root/.cache/R/pak

# System dependencies for common R packages
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    zlib1g-dev \
    pandoc \
    qpdf \
    && rm -rf /var/lib/apt/lists/*

# Create project directory
RUN mkdir -p /home/tidycreel
WORKDIR /home/tidycreel

FROM base AS deps

# Install deps the same way GH Actions does (pak + DESCRIPTION)
COPY DESCRIPTION NAMESPACE ./
RUN --mount=type=cache,target=/root/.cache/R,sharing=locked \
    Rscript -e 'options(repos = c(CRAN = "https://cloud.r-project.org"), pak.sysreqs = FALSE); install.packages("pak")' \
    && Rscript -e 'options(repos = c(CRAN = "https://cloud.r-project.org"), pak.sysreqs = FALSE); pak::local_install_deps(dependencies = c("Depends", "Imports", "LinkingTo"))' \
    && Rscript -e 'options(repos = c(CRAN = "https://cloud.r-project.org")); pak::pkg_install(c("devtools", "rcmdcheck", "testthat", "lintr", "styler", "readr"))'

FROM base AS final

COPY --from=deps /usr/local/lib/R/site-library /usr/local/lib/R/site-library

# Copy package files
COPY . .

# Install tidycreel to system library
RUN R_LIBS_USER="" R CMD INSTALL . --library=/usr/local/lib/R/site-library

# Set default command
CMD ["R"]
