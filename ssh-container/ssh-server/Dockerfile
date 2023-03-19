FROM ubuntu:jammy

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -qq update
RUN apt-get -qq install openssh-server
RUN apt-get -qq install krb5-user
RUN apt-get -qq install vim 
RUN apt-get -qq install nano
RUN apt-get -qq clean

RUN mkdir /var/run/sshd
RUN mkdir /var/empty

# configuration for the SSH server
COPY sshd_config /etc/ssh/sshd_config
RUN ssh-keygen -A

EXPOSE 22
CMD ["/usr/sbin/sshd", "-e", "-D"]

