#! /bin/bash

for file in linux/*;
    sudo setcap cap_ipc_lock+eip $file;
done
