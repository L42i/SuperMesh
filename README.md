# SuperMesh 

SuperMesh - formally **SüperMësh** - is a distributed camera system for object and motion tracking.

## Setup

1) Create a Virtual Environment

### Remote Machine(s)

The remote machine is the user's own laptop.
These setup steps enable the user to setup the complete cluster of Linux computers using mainly Ansible. 

1) Create A Python Virtual Environment and activate it.
  - This step is individual for all operating systems.
2) Install Ansible
    python3 -m pip install --user ansible



## Project Structure

```
SuperMesh/
├── config/
│   ├── ansible.cfg              # Ansible settings 
│   ├── bees.ini                 # Put the  Beelinks and the IPs
│   ├── cameras.yaml             # Where each camera is physically mounted (corner, height, room size)
│
├── setup/
│   ├── ping.yml                 # test to make sure we talking with all the BeeLinks
│
├── node/                        # Code that runs on each Beelink
│   └── depth_capture.py         # Blob detection + sends data to central over OSC
│
├── central/                     # Code that runs on the central computer
│   └── receiver.py              # Listens for blob data from all nodes over OSC, builds object map
│
├── concepts/                    # Proof of concept stuff / things we tested, stuff that worked,
│   │                            #   stuff that didn't
│   ├── depth_motion_detection.py  # motion detection + optical flow PoC (this one works)
│   ├── install_depth_camera.yml   # Tried to install RealSense SDK via Ansible (didn't work)
│
├── run_depth_cameras.yml        # Playbook to launch depth_capture.py on all nodes

```
## Contributors

Launched in Spring 2026 by:

- Zephyr Smith: zsmith88@gatech.edu
- Benjamin Morrissey: bmorrissey9@gatech.edu
- Mrityunjay Krishnakumar: mkrishnakumar9@gatech.edu

Georgia Institute of Technology
Atlanta, Georgia, USA
