ARG NUT_GITREF=master
ARG NUT_DIR=nut
ARG DIST_DIR=/dist
ARG NUT_USER=nut
ARG NUT_GROUP=nut
ARG NUT_GID=114
ARG NUT_RUNDIR=/var/run/nut

FROM alpine:latest as build

ARG NUT_GITREF
ARG NUT_DIR
ARG DIST_DIR
ARG NUT_USER
ARG NUT_GROUP
ARG NUT_RUNDIR

RUN apk add -U \
	git build-base python3 autoconf automake perl m4 libtool

RUN apk add -U \
	libusb-dev neon-dev libmodbus-dev nss-dev net-snmp-dev

RUN \
	git clone https://github.com/networkupstools/nut.git ${NUT_DIR} \
	&& cd ${NUT_DIR} \
	&& git checkout ${NUT_GITREF} \
	&& ./autogen.sh \
	&& ./configure \
		--prefix=/usr \
		--libexecdir=/usr/lib/nut \
		--without-wrap \
		--with-user=${NUT_USER} \
		--with-group=${NUT_GROUP} \
		--disable-static \
		--with-serial \
		--with-usb \
		--without-avahi \
		--with-snmp \
		--with-modbus \
		--with-neon \
		--without-powerman \
		--without-ipmi \
		--without-freeipmi \
		--with-libltdl \
		--without-cgi \
		--with-drvpath=/usr/lib/nut \
		--datadir=/usr/share/nut \
		--sysconfdir=/etc/nut \
		--with-statepath=${NUT_RUNDIR} \
		--with-altpidpath=${NUT_RUNDIR} \
		--with-udev-dir=/lib/udev \
		--with-nss \
		--with-openssl \
	&& make \
	&& make check

RUN \
	cd ${NUT_DIR} \
	&& make DESTDIR=${DIST_DIR} install

FROM alpine:latest

ARG DIST_DIR
ARG NUT_USER
ARG NUT_GROUP
ARG NUT_GID
ARG NUT_RUNDIR

RUN apk -U upgrade && apk add -U libusb libltdl neon nss net-snmp-libs libmodbus eudev hidapi

COPY --from=build ${DIST_DIR}/etc/ /etc/
COPY --from=build ${DIST_DIR}/usr/lib/ /usr/lib/
COPY --from=build ${DIST_DIR}/usr/bin/ /usr/bin/
COPY --from=build ${DIST_DIR}/usr/sbin/ /usr/sbin/
COPY --from=build ${DIST_DIR}/usr/share/ /usr/share/
RUN \
	addgroup -S -g ${NUT_GID} ${NUT_GROUP} \
	&& adduser -S -D -H -h ${NUT_RUNDIR} \
		-s /sbin/nologin -G ${NUT_GROUP} -g ${NUT_GROUP} ${NUT_USER}

RUN \
  mkdir -p ${NUT_RUNDIR} \
  && chown ${NUT_USER}:${NUT_GROUP} ${NUT_RUNDIR} \
  && chmod 0750 ${NUT_RUNDIR}

# Simple healthcheck to iterate over configured UPS'es attempting to fetch
# `driver.name` variable and exit on first failure setting up exit status = 1
HEALTHCHECK CMD \
	for ups in `upsc -l`; do \
		rc=1; \
		upsc $ups driver.name; \
		test $? -ne 0 && break; \
		rc=0; \
	done; \
	exit $rc

CMD upsdrvctl start && upsd -F
