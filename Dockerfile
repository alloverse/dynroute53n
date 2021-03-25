FROM amazonlinux:2
LABEL Name=dynroute53n Version=0.0.1

RUN yum  update -y \
    && yum install -y jq curl unzip sudo

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && sudo ./aws/install \
    && rm -rf *.zip aws

WORKDIR /aws
ADD . /aws/


CMD bash update-route53.bash
