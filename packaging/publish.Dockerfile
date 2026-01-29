# This Dockerfile is expected to run in CI to build the repository.

FROM alpine:edge AS usign-build
RUN apk add -U cmake build-base git
RUN git clone https://git.openwrt.org/project/usign.git /usign
WORKDIR /usign/build
RUN cmake /usign
RUN make

FROM alpine:edge AS publish
RUN apk add -U sequoia-sq
COPY --from=usign-build /usign/build/usign /usr/local/bin/
WORKDIR /build
COPY publish.sh /usr/local/bin
COPY *.apk .
COPY *.ipk .
RUN \
  --mount=type=secret,id=publish_key,required \
  KEYFILE=/run/secrets/publish_key publish.sh

FROM scratch
COPY --from=publish /build/out /
