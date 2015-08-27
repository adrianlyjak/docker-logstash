FROM       ubuntu:14.04

MAINTAINER Adrian Lyjak <adrianlyjak@gmail.com>

ENV        DEBIAN_FRONTEND noninteractive

# Install Java 8
RUN        apt-get update -qq && \
           apt-get install -qq curl software-properties-common software-properties-common > /dev/null && \
           apt-get update -qq && \
           add-apt-repository -y ppa:webupd8team/java && \
           apt-get update -qq && \
           echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \
           echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections && \
           apt-get install -qq oracle-java8-installer oracle-java8-set-default > /dev/null && \
           apt-get clean && rm -rf /var/lib/apt/lists/* && \
           rm -rf /var/cache/oracle-jdk8-installer
ENV 	     JAVA_HOME /usr/lib/jvm/java-8-oracle

# Install logstash dependencies
RUN        apt-get update -qq && \
           apt-get install -qq ruby ruby-dev jruby make rake git ca-certificates ca-certificates-java > /dev/null && \ 
           apt-get clean && rm -rf /var/lib/apt/lists/*


# Install logstash from package
RUN        wget -q -O - http://packages.elasticsearch.org/GPG-KEY-elasticsearch | apt-key add - && \
           echo 'deb http://packages.elasticsearch.org/logstash/1.5/debian stable main' > /etc/apt/sources.list.d/logstash.list && \
           apt-get update -qq && \
           apt-get install -qq logstash && \
           apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy and install patched version of gelf-rb/logstash-output-gelf
COPY       install/update-gelf.sh /opt/install/
RUN        /opt/install/update-gelf.sh

# Runtime scripts
COPY       bin/logstash-with-config /usr/local/bin/logstash-with-config
COPY       bin/substvars /usr/local/bin/substvars
COPY       bin/logstash /usr/local/bin/logstash

CMD        logstash-with-config