FROM alpine:edge
MAINTAINER Marco Sirianni <mail@mail.com>

# Aggiorno e installo i pacchetti necessari
RUN apk update
RUN apk upgrade
RUN apk add wget vim bash ruby ruby-dev ruby-rdoc syslog-ng syslog-ng-json syslog-ng-tags-parser

# Rimuovo la cache dei pacchetti appena installati
RUN rm -rf /var/cache/apk/*

# Installo la gemma necessaria per il funzionamento dell'applicazione
RUN gem install concurrent-ruby

# Configuro syslog-ng
COPY syslog-ng.conf /var/lib/syslog-ng/syslog-ng.conf
COPY pdb/ /var/lib/syslog-ng/pdb
COPY bin/ /var/lib/syslog-ng/bin

# Espongo la porta 6514 per poter usare RFC5425 (TLS)
EXPOSE 6514/tcp

#ENTRYPOINT  ["/usr/sbin/syslog-ng", "-F", "-f", "/var/lib/syslog-ng/syslog-ng.conf"]
