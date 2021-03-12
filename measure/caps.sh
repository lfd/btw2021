#! /bin/bash

for file in linux/*; do
    sudo setcap cap_ipc_lock+eip $file;
done
