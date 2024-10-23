# Stage 1: Build the EnhancedMap application
FROM mcr.microsoft.com/dotnet/core/sdk:2.2 AS build

# Set the working directory
WORKDIR /app

# Fix the outdated Debian repositories and install required dependencies
RUN sed -i 's|http://deb.debian.org/debian|http://archive.debian.org/debian|g' /etc/apt/sources.list && \
    sed -i '/security.debian.org/d' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y wget unzip

# Download the EnhancedMap zip file and extract it to /ems_compile
RUN wget https://github.com/andreakarasho/EnhancedMap/archive/refs/heads/master.zip -O enhancedmap.zip && \
    unzip enhancedmap.zip && \
    mkdir /ems_compile && \
    mv EnhancedMap-master/* /ems_compile/

# Set working directory to the compile folder
WORKDIR /ems_compile

# Restore the .NET project dependencies
RUN dotnet restore && dotnet publish -c Release -o /ems || true

# Stage 2: Create a smaller runtime image
FROM mcr.microsoft.com/dotnet/core/runtime:2.2

RUN sed -i 's|http://deb.debian.org/debian|http://archive.debian.org/debian|g' /etc/apt/sources.list && \
    sed -i '/security.debian.org/d' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends procps && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create user and group 'uomap' with UID and GID 1000
RUN groupadd --gid 1000 uomap && \
    useradd --uid 1000 --gid uomap --create-home uomap

# Set the working directory
WORKDIR /app

# Change ownership of the application files to the 'uomap' user
COPY --from=build /ems /app
RUN chown -R uomap:uomap /app

# Expose the necessary port
EXPOSE 8887

# Set the stop signal
STOPSIGNAL SIGINT

# Copy the combined uomap script
COPY entrypoint.sh /usr/local/bin/uomap
RUN chmod +x /usr/local/bin/uomap

# Ensure the /usr/local/bin directory is in the PATH (it usually is by default)
ENV PATH="/usr/local/bin:${PATH}"

# Switch to the 'uomap' user
USER uomap

# Set the custom entrypoint
ENTRYPOINT ["/usr/local/bin/uomap"]
