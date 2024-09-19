# syntax=docker/dockerfile:1
FROM public.ecr.aws/spacelift/runner-terraform:latest as deps

ARG ATMOS_VERSION=1.88.1
ARG TARGETARCH
ARG PRODUCT=terraform
ARG VERSION=1.5.7

# Temporarily elevating permissions
USER root

RUN apk add --no-cache wget && \
    wget -q -O atmos "https://github.com/cloudposse/atmos/releases/download/v${ATMOS_VERSION}/atmos_${ATMOS_VERSION}_linux_${TARGETARCH}"

RUN apk add --update --virtual .deps --no-cache gnupg && \
    cd /tmp && \
    wget https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_linux_amd64.zip && \
    wget https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_SHA256SUMS && \
    wget https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_SHA256SUMS.sig && \
    wget -qO- https://www.hashicorp.com/.well-known/pgp-key.txt | gpg --import && \
    gpg --verify ${PRODUCT}_${VERSION}_SHA256SUMS.sig ${PRODUCT}_${VERSION}_SHA256SUMS && \
    grep ${PRODUCT}_${VERSION}_linux_amd64.zip ${PRODUCT}_${VERSION}_SHA256SUMS | sha256sum -c && \
    unzip /tmp/${PRODUCT}_${VERSION}_linux_amd64.zip -d /tmp && \
    mv /tmp/${PRODUCT} /usr/local/bin/${PRODUCT} && \
    rm -f /tmp/${PRODUCT}_${VERSION}_linux_amd64.zip ${PRODUCT}_${VERSION}_SHA256SUMS ${VERSION}/${PRODUCT}_${VERSION}_SHA256SUMS.sig && \
    apk del .deps

# Back to the restricted "spacelift" user
USER spacelift

FROM alpine:latest as runner

COPY --from=deps --link atmos /usr/local/bin/atmos
COPY --from=deps --link /usr/local/bin/terraform /usr/local/bin/terraform

RUN apk upgrade && \
    apk add --no-cache procps curl bash git openssh jq && \
    chmod +x /usr/local/bin/atmos && \
    chmod +x /usr/local/bin/terraform

RUN terraform --version && atmos version

COPY rootfs/ /

WORKDIR /