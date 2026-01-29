# We need alpine:edge for apk v3.

FROM alpine:edge AS ipk-builder
ARG GIT_TAG=
RUN apk add -U tar
WORKDIR /src
ADD packaging/ipk ./
ADD update_glddns_com.sh data/usr/lib/ddns/
ADD glddns.com.json data/usr/share/ddns/custom/
RUN chmod a+x build.sh
ARG SOURCE_DATE_EPOCH
RUN ./build.sh

FROM alpine:edge AS apk-builder
WORKDIR /src
ADD packaging/apk update_glddns_com.sh glddns.com.json .
COPY --from=ipk-builder /src/control/control .
RUN chmod a+x build.sh
ARG SOURCE_DATE_EPOCH
RUN ./build.sh

FROM scratch
COPY --from=ipk-builder /glddns.ipk /
COPY --from=apk-builder /glddns.apk /
