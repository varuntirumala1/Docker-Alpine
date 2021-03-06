FROM alpine:latest as rootfs-stage

# environment
ENV REL=latest-stable
ENV ARCH=x86_64
ENV MIRROR=http://dl-cdn.alpinelinux.org/alpine
ENV PACKAGES=alpine-baselayout,\
alpine-keys,\
apk-tools,\
busybox,\
libc-utils,\
xz

# install packages
RUN apk add --no-cache \
	bash \
	curl \
	tzdata \
	xz

# fetch builder script from gliderlabs
RUN curl -o /mkimage-alpine.bash -L https://raw.githubusercontent.com/gliderlabs/docker-alpine/master/builder/scripts/mkimage-alpine.bash && \
 chmod +x /mkimage-alpine.bash && ./mkimage-alpine.bash  && mkdir /root-out && \
 tar xf /rootfs.tar.xz -C /root-out && \
 sed -i -e 's/^root::/root:!:/' /root-out/etc/shadow

# Runtime stage
FROM scratch
COPY --from=rootfs-stage /root-out/ /

RUN apk add --no-cache curl wget patch tar bash \
	ca-certificates coreutils procps shadow tzdata nano libc6-compat

RUN overlay_url="$(curl -s https://api.github.com/repos/just-containers/s6-overlay/releases/latest | \
  grep -o "browser_download_url.*s6-overlay-amd64-installer" | cut -d ":" -f 2,3 | tr -d \" | sort -u)" \
&& wget -O /tmp/s6-overlay-amd64-installer $overlay_url \
&& chmod +x /tmp/s6-overlay-amd64-installer && /tmp/s6-overlay-amd64-installer / && rm /tmp/s6-overlay-amd64-installer \
&& mkdir -p /etc/fix-attrs.d \
&& mkdir -p /etc/services.d

COPY patch/ /tmp/patch

# environment variables
ENV PS1="$(whoami)@$(hostname):$(pwd)\\$ " \
HOME="/root" \
TERM="xterm"

RUN groupmod -g 1000 users && \
 useradd -u 911 -U -d /config -s /bin/false abc && \
 usermod -G users abc && \
 mkdir -p \
	/app \
	/config \
	/defaults && \
 mv /usr/bin/with-contenv /usr/bin/with-contenvb && \
 patch -u /etc/s6/init/init-stage2 -i /tmp/patch/etc/s6/init/init-stage2.patch && \
 rm -rf /tmp/*

# add local files
COPY root/ /

ENTRYPOINT ["/init"]
