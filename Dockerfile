
FROM ubuntu:14.04
MAINTAINER DFKI

RUN apt-get update && \
    apt-get install -y \
        git \
        curl \
        unzip \
        openjdk-7-jdk \
        maven \
        cmake \
        build-essential \
        libassimp-dev libjansson-dev libapr1-dev \
        libboost-system-dev libboost-thread-dev \
        libboost-filesystem-dev libboost-program-options-dev \
        libssl-dev \
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# setup wildfly
ENV WILDFLY_VERSION 8.2.1.Final
ENV JBOSS_DIR /opt/jboss
ENV JBOSS_HOME $JBOSS_DIR/wildfly
ENV JBOSS_CONFIG $JBOSS_HOME/standalone/configuration

RUN groupadd -r jboss -g 1000 && \
    useradd -u 1000 -r -g jboss -m -d $JBOSS_DIR -s /sbin/nologin -c "JBoss user" jboss && \
    chmod 755 $JBOSS_DIR

RUN cd $JBOSS_DIR && \
    curl -SL https://download.jboss.org/wildfly/$WILDFLY_VERSION/wildfly-$WILDFLY_VERSION.tar.gz \
    | tar -xz && \
    ln -s wildfly-$WILDFLY_VERSION wildfly

# setup modeshape
ENV MODESHAPE_VERSION 4.1.0.Final

RUN curl -SL -o modeshape.zip https://download.jboss.org/modeshape/$MODESHAPE_VERSION/modeshape-$MODESHAPE_VERSION-jboss-wf8-dist.zip && \
    unzip -q modeshape.zip -d $JBOSS_HOME && \
    rm modeshape.zip

# setup atlas-server
ENV ATLAS_HOME /opt/atlas
ENV STOMP_USER stomp-msg-user
ENV STOMP_PASS stomp-msg-passwd

RUN cd /opt && \
    git clone --recursive https://github.com/dfki-asr/atlas.git

# configure Wildfly and Modeshape
COPY configuration/*.* $JBOSS_CONFIG/
RUN cd $JBOSS_HOME && \
    bin/add-user.sh -a $STOMP_USER $STOMP_PASS --silent && \
    echo "$STOMP_USER=guest" >> $JBOSS_CONFIG/application-roles.properties

VOLUME $JBOSS_HOME/standalone/data

# build atlas-server
RUN cd $ATLAS_HOME && \
    mvn install && \
    cp atlas-server/target/atlas-1.1.0.war $JBOSS_HOME/standalone/deployments/

# build atlas-worker dependencies
RUN mkdir -p $ATLAS_HOME/contrib

RUN curl -SL -o assimp-3.1.1.zip http://downloads.sourceforge.net/project/assimp/assimp-3.1/assimp-3.1.1_no_test_models.zip && \
    unzip -q assimp-3.1.1.zip -d $ATLAS_HOME/contrib && \
    rm assimp-3.1.1.zip && \
    cd $ATLAS_HOME/contrib/assimp-3.1.1 && \
    mkdir build && \
    cd build && \
    cmake ../ && \
    make install && \
    rm -r $ATLAS_HOME/contrib/assimp-3.1.1

RUN cd $ATLAS_HOME/contrib && \
    curl -SL http://www.eu.apache.org/dist/activemq/activemq-cpp/3.8.4/activemq-cpp-library-3.8.4-src.tar.gz \
    | tar -xz && \
    cd activemq-cpp-library-3.8.4 && \
    ./configure && \
    make install && \
    rm -r $ATLAS_HOME/contrib/activemq-cpp-library-3.8.4

RUN cd $ATLAS_HOME/contrib && \
    curl -SL http://pocoproject.org/releases/poco-1.6.0/poco-1.6.0-all.tar.gz \
    | tar -xz && \
    cd poco-1.6.0-all && \
    ./configure --cflags="-Wno-pragmas" --no-tests --no-samples --omit=Data/MySQL,Data/ODBC && \
    make install && \
    rm -r $ATLAS_HOME/contrib/poco-1.6.0-all

# build atlas-worker
RUN mkdir -p $ATLAS_HOME/atlas-worker-build && \
    cd $ATLAS_HOME/atlas-worker-build && \
    cmake ../atlas-worker \
        -DAPR_INCLUDE_DIR=/usr/include/apr-1.0 \
        -DActiveMQ-CPP_INCLUDE_DIR=/usr/local/include/activemq-cpp-3.8.4 && \
    make install && \
    rm -r $ATLAS_HOME/atlas-worker-build


COPY bootstrap.sh $ATLAS_HOME/bootstrap.sh
RUN chmod a+x $ATLAS_HOME/bootstrap.sh

EXPOSE 8080

# CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0"]

# CMD ["/bin/bash"]

CMD ["/opt/atlas/bootstrap.sh"]

