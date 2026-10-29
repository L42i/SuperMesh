# Tracking

## Repository Breakdown
```
SuperMesh/
├── config/
│   ├── ansible.cfg              # Ansible settings 
│   ├── bees.ini                 # The Beelinks and their IPs (for Ansible)
│   ├── cameras.yaml             # Where each camera is physically mounted (corner height, room size)
│
├── setup/
│   ├── ping.yml                 # Test to make sure we can communicate with all the BeeLinks nodes
│
├── concepts/
│   ├── headless_script.py  # The tracking script for each of the nodes
│   ├── master_enhanced.py  # The current master script for the master computer
│   ├── master_test.py  # WIP master script (will replace master_enhanced.py)
│   ├── requirements.txt  # Contains the necessary libraries
│
├── run_depth_cameras.yml        # Playbook to run the tracking script on all nodes
```

## High-level Overview
Our tracking system is being handled by 4 beelink nodes and a master computer. 

These nodes are each running a tracking script (headless_script.py). Each of the 4 nodes will detect a person and send their own coordinate of that person as an OSC message:

> address: /person/device_ip message: person_count, gx, gz, gy, conf
- device_ip: IP of the node
-  person_count: How many people are being seen.
- gx: X coordinate.
- gz: Z coordinate.
- gy: Y coordinate (not used)
- conf: Confidence score

These OSC messages are sent to the master computer that is running (master_test.py). This script will process the incoming OSC messages and combine the 4 coordinates into one, for a single, stable coordinate. 

This finalized coordinate can be sent to the synth client through OSC (/person) for processing. Alongside it will also be an OSC message (/people) for how many people are detected.

> address: /person message: float(i), p.x, p.z
- float(i): Person ID
- p.x: X coordinate.
- p.z: Z coordinate.

> address: /people message: count
- count: How many people are detected.

## Additional Details
**Make sure that all the devices involved are connected to the same WiFi connection.**

When downloading the libraries via requirements.txt, ensure that you are in a virtual environment for this.

<u>run_depth_camera.yaml</u> is the Ansible playbook that is used to run the tracking script (headless_script.py) on all of the nodes at once.

The command to run this playbook is:

> ansible-playbook -i config/bees.ini run_depth_cameras.yaml --ask-pass

When prompted, the password to SSH into each node is <u>"henryhenrik" (no quotes)</u>.

**PLEASE ensure that the tracking script (headless_script.py) is sending OSC messages to the <u>master computer's IP address and port</u> and that the master script (master_enhanced.py) is sending OSC messages to the <u>receiver's IP address and port</u>.**

The master script (master_enhanced), if run correctly, will display a GUI that allows you to observe the people detected. The features, alongside with their controls, are displayed at the bottom.



