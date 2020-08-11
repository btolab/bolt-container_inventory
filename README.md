# Bolt Container Inventory

This is a bolt container inventory plugin used to enumerate the currently running containers on your local system. Currently there is limited functionality but the plan is to add additional features to cover more runtimes and use cases.

## Description
Bolt can use docker as a transport but there hasn't been a way to easily list the containers without this plugin. This plugin will run `docker ps --filter status=running -q` from the command line to return the current list of running containers.  At the moment there is no way to alter this list with configuration.



## Setup
You will need to have the `puppetlabs/ruby_task_helper` module and this module installed in your bolt module path. 

## Configuration
Ensure you inventory uses the plugin `container_inventory` name like below. 

```
---
groups:
  - name: my_containers
    config:
      transport: docker
    targets:
      _plugin: container_inventory
```


## Usage

```
bolt command run 'uname -i' --targets=standard -i inventory.yaml 
Started on docker://bb8531de599e...
Finished on docker://bb8531de599e:
  STDOUT:
    x86_64
Successful on 1 target: docker://bb8531de599e
Ran on 1 target in 1.07 sec
```
