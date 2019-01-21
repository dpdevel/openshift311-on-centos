#!/bin/bash

yum -y update

yum -y install tmux

tmux new-session -d -s installcentos

chmod +x /root/run.sh

tmux send -t installcentos /root/run.sh ENTER