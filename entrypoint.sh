#!/bin/bash
ssh-keygen -A
echo "Port 1024" | sudo tee -a /etc/ssh/sshd_config
sudo service ssh start
# mv ~/super_client_configuration_file.xml ~/workspace
/bin/bash
# ros2 daemon stop
# ros2 daemon start