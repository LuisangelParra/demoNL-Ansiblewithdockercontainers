# DEMO ANSIBLE

### Requisitos

- Docker (necesario para esta demo).
- Tener instalado Ansible en tu sistema.

### Instalación de Docker

1. Add Docker's official GPG key:

    ```bash
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    ```

2. Add the repository to Apt sources:

    ```bash
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    ```

3. Install the Docker packages.

    ```bash
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    ```

### Instalación de Ansible

1. Actualiza los paquetes de tu sistema:

   ```bash
   sudo apt update
   ```

2. Instala las dependencias necesarias:

   ```bash
   sudo apt install -y software-properties-common
   ```

3. Agrega el repositorio de Ansible:

   ```bash
   sudo add-apt-repository ppa:ansible/ansible
   ```

4. Actualiza la lista de paquetes:

   ```bash
   sudo apt update
   ```

5. Instala Ansible:

   ```bash
   sudo apt install -y ansible
   ```

6. Verifica la instalación:

   ```bash
   ansible --version
   ```


### Ejecución de la demo

Para que los contenedores configuren una clave SSH al iniciar, podemos agregar el archivo de clave pública en el contenedor durante la construcción de la imagen. De esta forma, Ansible puede conectarse sin necesidad de usar una contraseña.

### 1. Genera una Clave SSH Pública (si no tienes una)

Si aún no tienes una clave SSH en tu máquina local, crea una con el siguiente comando:

```bash
ssh-keygen -t rsa -b 2048 -f ~/.ssh/ansible_key -N ""
```

Esto generará dos archivos:
- `~/.ssh/ansible_key` (clave privada)
- `~/.ssh/ansible_key.pub` (clave pública)

### 2. Modifica el `Dockerfile` para Configurar la Clave Pública

Edita el archivo `Dockerfile` para que la clave pública se copie al contenedor y se configure en el archivo `authorized_keys` del usuario `root`.

```dockerfile
FROM ubuntu:latest

# Instala SSH y Python
RUN apt-get update && apt-get install -y openssh-server python3

# Configura SSH
RUN mkdir /var/run/sshd
RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
RUN echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

# Copia la clave pública al contenedor
COPY ~/.ssh/ansible_key.pub /root/.ssh/authorized_keys

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
```

El error ocurre porque Docker no reconoce el uso de `~` para la ruta de tu directorio personal. En su lugar, debes usar una ruta absoluta o copiar el archivo de clave pública al mismo directorio donde estás construyendo la imagen.

Aquí tienes dos formas de solucionarlo:

#### Posible fallo por permisos en ./ssh (Solución rapida)

1. Copia el archivo `ansible_key.pub`:

   ```bash
   cp ~/.ssh/ansible_key.pub .
   ```

2. Actualiza el `Dockerfile` para usar el archivo en el directorio actual:

   ```dockerfile
   COPY ansible_key.pub /root/.ssh/authorized_keys
   ```

Luego, reconstruye la imagen Docker y lanza el contenedor. Esto debería resolver el problema y copiar la clave pública correctamente.

### 3. Construye la Imagen Docker y Crea los Contenedores

Ahora necesitas construir la imagen para los contenedores:

   ```bash
   docker build -t ansible-server .
   ```

Luego, inicia los contenedores:

   ```bash
   docker run -d --name server1 ansible-server
   docker run -d --name server2 ansible-server
   docker run -d --name server3 ansible-server
   ```

Obtén las direcciones IP de los contenedores para configurarlos en Ansible:
   
   ```bash
   docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' server1
   docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' server2
   docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' server3
   ```

Prueba las conexiones ssh a los servidores:

   ```bash
   ssh root@<IP_SERVER1>
   ssh root@<IP_SERVER2>
   ssh root@<IP_SERVER3>
   ```

### 4. Configura el Inventario de Ansible para Usar la Clave Privada

En el archivo de inventario `hosts`, configura el acceso con la clave privada:

   ```ini
   [demo_servers]
   server1 ansible_host=<IP_SERVER1> ansible_user=root ansible_ssh_private_key_file=~/.ssh/ansible_key
   server2 ansible_host=<IP_SERVER2> ansible_user=root ansible_ssh_private_key_file=~/.ssh/ansible_key
   server3 ansible_host=<IP_SERVER3> ansible_user=root ansible_ssh_private_key_file=~/.ssh/ansible_key
   ```

Escribe un playbook de Ansible para hacer alguna tarea simple en estos servidores, por ejemplo, instalar nginx en cada uno.

Crea un archivo llamado install_nginx.yml:

   ```yaml
   - name: Instala Nginx en servidores demo
   hosts: demo_servers
   become: yes
   tasks:
      - name: Actualiza apt
         apt:
         update_cache: yes

      - name: Instala Nginx
         apt:
         name: nginx
         state: present
   ```

### 5. Ejecuta la Demo

Ejecuta el playbook:

   ```bash
   ansible-playbook -i hosts install_nginx.yml
   ```

Verifica el resultado accediendo a cada contenedor y verificando que nginx esté instalado.

   ```bash
   docker exec -it server1 nginx -v
   docker exec -it server2 nginx -v
   docker exec -it server3 nginx -v
   ```