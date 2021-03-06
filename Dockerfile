FROM python:3.8-alpine3.12 as py-ea
ARG ELASTALERT_VERSION=v0.2.4
ENV ELASTALERT_VERSION=${ELASTALERT_VERSION}
ARG ELASTALERT_URL=https://github.com/Yelp/elastalert/archive/$ELASTALERT_VERSION.zip
ENV ELASTALERT_URL=${ELASTALERT_URL}
ENV ELASTALERT_HOME /opt/elastalert

WORKDIR /opt

RUN apk add --update --no-cache ca-certificates openssl-dev openssl python3-dev python3 libffi-dev gcc musl-dev wget && \
    wget -O elastalert.zip "${ELASTALERT_URL}" && \
    unzip elastalert.zip && \
    rm elastalert.zip && \
    mv e* "${ELASTALERT_HOME}"

WORKDIR "${ELASTALERT_HOME}"

# Fix until Fix LineNotify #2783(https://github.com/Yelp/elastalert/pull/2783) is merged
# Fix until Bugfix and better error handling on zabbix alerter #2640(https://github.com/Yelp/elastalert/pull/2640) is merged
# Fix until Fix PagerTree #2934(https://github.com/Yelp/elastalert/pull/2934) is merged
# Fix until Fix PyYAML Deprecated Warning #3000(https://github.com/Yelp/elastalert/pull/3000) is merged
COPY patches/loaders.py /opt/elastalert/elastalert/loaders.py
# Fix until Bugfix and better error handling on zabbix alerter #2640(https://github.com/Yelp/elastalert/pull/2640) is merged
COPY patches/zabbix.py /opt/elastalert/elastalert/zabbix.py
# Fix until Fix SNS(Program & Docs) #2793(https://github.com/Yelp/elastalert/pull/2793) is merged
# Fix until Fix Stomp #3024(https://github.com/Yelp/elastalert/pull/3024) is merged
COPY patches/alerts.py /opt/elastalert/elastalert/alerts.py
# Fix until Fix elasticsearch-py versionup test_rule.py error #3046(https://github.com/Yelp/elastalert/pull/3046) is merged
COPY patches/test_rule.py /opt/elastalert/elastalert/test_rule.py
# Fix until Fix initializing self.thread_data.alerts_sent for running elastalert-test-rule #2991(https://github.com/Yelp/elastalert/pull/2991) is merged
COPY patches/elastalert.py /opt/elastalert/elastalert/elastalert.py
# Fix until Change Library blist to sortedcontainers #3019(https://github.com/Yelp/elastalert/pull/3019) is merged
COPY patches/ruletypes.py /opt/elastalert/elastalert/ruletypes.py
# Fix until Fix PyYAML Deprecated Warning #3000(https://github.com/Yelp/elastalert/pull/3000) is merged
COPY patches/create_index.py /opt/elastalert/elastalert/create_index.py
# Fix until Sync requirements.txt and setup.py & update py-zabbix #2818(https://github.com/Yelp/elastalert/pull/2818) is merged
# Fix until Remove configparser #3010(https://github.com/Yelp/elastalert/pull/3010) is merged
# Fix until Pin tzlocal to 2.1 in setup.py #3013(https://github.com/Yelp/elastalert/pull/3013) is merged
# Fix until Change Library blist to sortedcontainers #3019(https://github.com/Yelp/elastalert/pull/3019) is merged
COPY patches/setup.py /opt/elastalert/setup.py
# Fix until Pin elasticsearch to 7.0.0 in requirements.txt #2684 (https://github.com/Yelp/elastalert/pull/2684)
# Fix until version 0.2.1 broken for python 3.7 (jira) #2437 (https://github.com/Yelp/elastalert/issues/2437)
# Fix until Sync requirements.txt and setup.py & update py-zabbix #2818(https://github.com/Yelp/elastalert/pull/2818) is merged
# Fix until Remove configparser #3010(https://github.com/Yelp/elastalert/pull/3010) is merged
# Fix until Pin tzlocal to 2.1 in setup.py #3013(https://github.com/Yelp/elastalert/pull/3013) is merged
# Fix until Change Library blist to sortedcontainers #3019(https://github.com/Yelp/elastalert/pull/3019) is merged
COPY patches/requirements.txt  /opt/elastalert/requirements.txt 

RUN python3 setup.py install

FROM node:14.15-alpine3.12
LABEL maintainer="John Susek <john@johnsolo.net>"
ENV TZ Etc/UTC
ENV PATH /home/node/.local/bin:$PATH

RUN apk add --update --no-cache curl tzdata python3 ca-certificates openssl-dev openssl python3-dev gcc musl-dev make libffi-dev libmagic py3-pip

COPY --from=py-ea /usr/lib/python3.8/site-packages /usr/lib/python3.8/site-packages
COPY --from=py-ea /opt/elastalert /opt/elastalert
# COPY --from=py-ea /usr/bin/elastalert* /usr/bin/

WORKDIR /opt/elastalert-server
COPY . /opt/elastalert-server

RUN npm install --production --quiet
COPY config/elastalert.yaml /opt/elastalert/config.yaml
COPY config/config.json config/config.json
COPY rule_templates/ /opt/elastalert/rule_templates
COPY elastalert_modules/ /opt/elastalert/elastalert_modules

# Add default rules directory
# Set permission as unpriviledged user (1000:1000), compatible with Kubernetes
RUN mkdir -p /opt/elastalert/rules/ /opt/elastalert/server_data/tests/ \
    && chown -R node:node /opt

RUN pip3 install --no-cache-dir --upgrade pip

USER node

EXPOSE 3030

WORKDIR /opt/elastalert

RUN pip3 install --no-cache-dir -r requirements.txt --user

WORKDIR /opt/elastalert-server

ENTRYPOINT ["npm", "start"]
