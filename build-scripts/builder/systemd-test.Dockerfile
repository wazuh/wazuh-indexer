# Minimal systemd-enabled Ubuntu image for DEB package tests.
#
# The CI runner is itself a container without systemd as PID 1, so the
# wazuh-indexer maintainer scripts (which call systemctl) cannot run on the
# host. The DEB tests therefore run inside this image booted with /sbin/init,
# the Debian-family equivalent of redhat/ubi9-init used by the RPM tests.
#
# Built from AWS ECR Public (no unauthenticated pull-rate limits on CodeBuild),
# mirroring build-scripts/builder/Dockerfile, instead of a Docker Hub systemd
# image which trips `toomanyrequests`.
FROM public.ecr.aws/ubuntu/ubuntu:jammy

ENV DEBIAN_FRONTEND=noninteractive
ENV container=docker

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        systemd \
        systemd-sysv \
        dbus && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    # Drop units that are pointless (and slow/noisy) inside a container.
    rm -f /lib/systemd/system/systemd-update-utmp* \
          /lib/systemd/system/systemd-tmpfiles-setup* \
          /lib/systemd/system/sysinit.target.wants/systemd-firstboot.service \
          /lib/systemd/system/multi-user.target.wants/systemd-update-utmp-runlevel.service

STOPSIGNAL SIGRTMIN+3

CMD ["/sbin/init"]
