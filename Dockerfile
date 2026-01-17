FROM registry.suse.com/bci/bci-base:16.0 AS builder
ARG SOURCE_DATE_EPOCH
WORKDIR /src
ADD ipk ./
ADD update_glddns_com.sh data/usr/lib/ddns/
ADD ipk/glddns.com.json data/usr/share/ddns/custom/
RUN chmod a+x build.sh
RUN ./build.sh

FROM scratch
COPY --from=builder /glddns.ipk /
