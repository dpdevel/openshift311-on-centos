#!/bin/bash

source env.sh

terraform init

terraform apply -auto-approve

terraform show

ssh -t root@`cat ip.tmp` 'tmux attach'