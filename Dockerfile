ARG BASE_IMAGE=ubuntu:bionic-20200311
FROM $BASE_IMAGE
ENV BASE_IMAGE=$BASE_IMAGE

LABEL maintainer "Manoel Jansen <manoel.jansen@yahoo.com.br>"

#===================================================
#Based on appium/appium docker from Srinivasan Sekar
#===================================================


ENV DEBIAN_FRONTEND=noninteractive
#=============
# Set WORKDIR
#=============
WORKDIR /root

#==================
# General Packages
#------------------
# openjdk-8-jdk
#   Java
# ca-certificates
#   SSL client
# tzdata
#   Timezone
# zip
#   Make a zip file
# unzip
#   Unzip zip file
# curl
#   Transfer data from or to a server
# wget
#   Network downloader
# libqt5webkit5
#   Web content engine (Fix issue in Android)
# libgconf-2-4
#   Required package for chrome and chromedriver to run on Linux
# xvfb
#   X virtual framebuffer
# gnupg
#   Encryption software. It is needed for nodejs
# salt-minion
#   Infrastructure management (client-side)
#==================
RUN apt-get -qqy update && \
    apt-get -qqy --no-install-recommends install \
    openjdk-8-jdk \
    ca-certificates \
    tzdata \
    zip \
    unzip \
    curl \
    wget \
    libqt5webkit5 \
    libgconf-2-4 \
    xvfb \
    gnupg \
    salt-minion \
  && rm -rf /var/lib/apt/lists/*

#===============
# Set JAVA_HOME
#===============
ENV JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64/jre" \
    PATH=$PATH:$JAVA_HOME/bin

#=====================
# Install Android SDK
#=====================
ARG SDK_VERSION=sdk-tools-linux-3859397
ARG ANDROID_BUILD_TOOLS_VERSION=26.0.0
ARG ANDROID_PLATFORM_VERSION="android-25"

ENV SDK_VERSION=$SDK_VERSION \
    ANDROID_BUILD_TOOLS_VERSION=$ANDROID_BUILD_TOOLS_VERSION \
    ANDROID_HOME=/root

RUN wget -O tools.zip https://dl.google.com/android/repository/${SDK_VERSION}.zip && \
    unzip tools.zip && rm tools.zip && \
    chmod a+x -R $ANDROID_HOME && \
    chown -R root:root $ANDROID_HOME

ENV PATH=$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin


RUN mkdir -p ~/.android && \
    touch ~/.android/repositories.cfg && \
    echo y | sdkmanager "platform-tools" && \
    echo y | sdkmanager "build-tools;$ANDROID_BUILD_TOOLS_VERSION" && \
    echo y | sdkmanager "platforms;$ANDROID_PLATFORM_VERSION"

ENV PATH=$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools

#====================================
# Install latest nodejs, npm, appium
# Using this workaround to install Appium -> https://github.com/appium/appium/issues/10020 -> Please remove this workaround asap
#====================================

ARG APPIUM_VERSION=1.17.1
ENV APPIUM_VERSION=$APPIUM_VERSION

RUN curl -sL https://deb.nodesource.com/setup_12.x | bash && \
    apt-get -qqy install nodejs && \
    npm install -g appium@${APPIUM_VERSION} --unsafe-perm=true --allow-root && \
    npm cache clean --force && \
    apt-get remove --purge -y npm && \
    apt-get autoremove --purge -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    apt-get clean

#===================================
# Install Python3
#===================================
RUN apt-get update && \
    apt-get install -y python3 python3-pip && \
    apt-get install -y python3-pip

#====================================
# Install KVM
#====================================
RUN apt-get install qemu-kvm libvirt-bin ubuntu-vm-builder bridge-utils && \
    adduser root kvm && \
    chown root /dev/kvm && \
    adduser root libvirtd


#===================================
# Install RobotFramework & Appium library
#===================================
RUN pip3 install robotframework robotframework-seleniumlibrary robotframework-appiumlibrary==1.5.0.2 | grep "Successfully installed"

#===================================
# Creating emulator
#===================================
RUN echo y | sdkmanager 'system-images;android-29;default;x86_64' && \
echo no | avdmanager create avd -n emulator -k 'system-images;android-29;default;x86_64'

#================================
# APPIUM Test Distribution (ATD)
#================================
ARG ATD_VERSION=1.2
ENV ATD_VERSION=$ATD_VERSION
RUN wget -nv -O RemoteAppiumManager.jar "https://github.com/AppiumTestDistribution/ATD-Remote/releases/download/${ATD_VERSION}/RemoteAppiumManager-${ATD_VERSION}.jar"
#==================================
# Fix Issue with timezone mismatch
#==================================
ENV TZ="US/Pacific"
RUN echo "${TZ}" > /etc/timezone
#===============
# Expose Ports
#---------------
# 4723
#   Appium port
# 4567
#   ATD port
#===============
EXPOSE 4723
EXPOSE 4567

#====================================================
# Scripts to run appium and connect to Selenium Grid
#====================================================
COPY entry_point.sh \
     wireless_autoconnect.sh \
     /root/appium/

RUN chmod +x /root/appium/entry_point.sh && \
    chmod +x /root/appium/wireless_autoconnect.sh


#========================================
# Run xvfb and appium server
#========================================
CMD /root/appium/wireless_autoconnect.sh && /root/appium/entry_point.sh
