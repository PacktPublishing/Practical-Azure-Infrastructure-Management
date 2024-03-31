#!/bin/bash
sudo apt update
sudo apt install -y software-properties-common
sudo apt install -y python3-pip
sudo pip3 install --upgrade pip
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible
sudo ansible-galaxy collection install azure.azcollection --force
sudo pip3 install -r /root/.ansible/collections/ansible_collections/azure/azcollection/requirements-azure.txt