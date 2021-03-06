FROM debian:9

VOLUME ["/var/log", "/var/spool/postfix"]
EXPOSE 25

ENV HOST=localhost \
    DOMAIN=localdomain \
    MAILNAME=localdomain \
    MAIL_RELAY_HOST='' \
    MAIL_RELAY_PORT='' \
    MAIL_RELAY_USER='' \
    MAIL_RELAY_PASS='' \
    MAIL_VIRTUAL_FORCE_TO='' \
    MAIL_VIRTUAL_ADDRESSES='' \
    MAIL_VIRTUAL_DEFAULT='' \
    MAIL_CANONICAL_DOMAINS='' \
    MAIL_NON_CANONICAL_PREFIX='' \
    MAIL_NON_CANONICAL_DEFAULT='' \
    MESSAGE_SIZE_LIMIT=26214400

RUN apt-get update && \
    apt-get upgrade -yqq && \
    echo "postfix postfix/mailname string $MAILNAME" | debconf-set-selections && \
    echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections && \
    apt-get install -yqq postfix rsyslog iproute2 wget && \
    apt-get clean -yqq && \
    apt-get autoclean -yqq && \
    apt-get autoremove -yqq && \
    rm -rf /var/cache/apt/archives/* /var/cache/apt/*.bin /var/lib/apt/lists/*

ARG DUMB_INIT=1.2.1
RUN wget -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT}/dumb-init_${DUMB_INIT}_amd64 && \
    chmod +x /usr/local/bin/dumb-init

ADD postfix /etc/postfix
ADD entrypoint sendmail_test /usr/local/bin/

RUN chmod a+rx /usr/local/bin/* && \
    /usr/sbin/postconf -e smtp_tls_security_level=may && \
    /usr/sbin/postconf -e smtp_sasl_auth_enable=yes && \
    /usr/sbin/postconf -e smtp_sasl_password_maps=hash:/etc/postfix/sasl_passwd && \
    /usr/sbin/postconf -e smtp_sasl_security_options=noanonymous && \
    /usr/sbin/postconf -e myhostname=$HOST && \
    /usr/sbin/postconf -e mydomain=$DOMAIN && \
    /usr/sbin/postconf -e mydestination=localhost && \
    /usr/sbin/postconf -e mynetworks='127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128' && \
    /usr/sbin/postconf -e inet_interfaces=loopback-only && \
    /usr/sbin/postconf -e smtp_helo_name=\$myhostname.\$mydomain && \
    /usr/sbin/postconf -e virtual_maps='hash:/etc/postfix/virtual, regexp:/etc/postfix/virtual_regexp' && \
    /usr/sbin/postconf -e sender_canonical_maps=regexp:/etc/postfix/sender_canonical_regexp && \
    /usr/sbin/postconf compatibility_level=2 && \
    /usr/sbin/postmap /etc/postfix/sasl_passwd && \
    /usr/sbin/postmap /etc/postfix/virtual_regexp && \
    /usr/sbin/postmap /etc/postfix/virtual && \
    /usr/sbin/postmap /etc/postfix/sender_canonical_regexp

ENTRYPOINT ["/usr/local/bin/dumb-init", "--", "/usr/local/bin/entrypoint"]
CMD ["tail", "-f", "/var/log/mail.log"]
