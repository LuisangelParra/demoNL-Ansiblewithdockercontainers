FROM ubuntu:latest

# Instala SSH y Python
RUN apt-get update && apt-get install -y openssh-server python3

# Configura SSH
RUN mkdir /var/run/sshd
RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
RUN echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

# Copia la clave pública al contenedor
COPY ansible_key.pub /root/.ssh/authorized_keys

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
