FROM ubuntu:20.04
LABEL Name=dynroute53n Version=0.0.1

RUN apt-get -y update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y tzdata awscli jq curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /app
ADD . /app/

CMD bash update-route53.bash
