# F1TENTH gym environment ROS2 communication bridge
This is a containerized ROS communication bridge for the F1TENTH gym environment that turns it into a simulation in ROS2.

# Installation

**Supported System:**

- Ubuntu (tested on 20.04) native with ROS 2
- Ubuntu (tested on 20.04) with an NVIDIA gpu and nvidia-docker2 support
- Windows 10, macOS, and Ubuntu without an NVIDIA gpu (using noVNC)

This installation guide will be split into instruction for installing the ROS 2 package natively, and for systems with or without an NVIDIA gpu in Docker containers.

## Native on Ubuntu 20.04

**Install the following dependencies:**
- **ROS 2** Follow the instructions [here](https://docs.ros.org/en/foxy/Installation.html) to install ROS 2 Foxy.
- **F1TENTH Gym**
  ```bash
  git clone https://github.com/s-hliao/usps-gym
  cd usps-gym && pip3 install -e .
  ```

**Installing the simulation:**
- Create a workspace: ```cd $HOME && mkdir -p sim_ws/src```
- Clone the repo into the workspace:
  ```bash
  cd $HOME/sim_ws/src
  git clone https://github.com/f1tenth/usps-docker
  ```
- Update correct parameter for path to map file:
  Go to `sim.yaml` [https://github.com/s-hliao/usps-docker/blob/main/config/sim.yaml](https://github.com/f1tenth/usps-docker/blob/main/config/sim.yaml) in your cloned repo, change the `map_path` parameter to point to the correct location. It should be `'<your_home_dir>/sim_ws/src/usps-docker/maps/levine'`
- Install dependencies with rosdep:
  ```bash
  source /opt/ros/foxy/setup.bash
  cd ..
  rosdep install -i --from-path src --rosdistro foxy -y
  ```
- Build the workspace: ```colcon build```

## Docker Installation (no GPU):

**Installing the simulation:**

1. Create a workspace: ```cd $HOME && mkdir -p sim_ws/src```
2. Clone the repo into the workspace:
  ```bash
  cd $HOME/sim_ws/src
  git clone https://github.com/s-hliao/usps-docker
  git clone https://github.com/s-hliao/usps-gym
  git clone https://github.com/Zedonkay/USPS
  ```
3. Build the docker image by:
```bash
$ cd usps-docker
$ docker build -t usps-docker -f Dockerfile .
```

## Without an NVIDIA gpu:

**Install the following dependencies:**

If your system does not support nvidia-docker2, noVNC will have to be used to forward the display.
- Again you'll need **Docker**. Follow the instruction from above.
- Additionally you'll need **docker-compose**. Follow the instruction [here](https://docs.docker.com/compose/install/) to install docker-compose.

**Installing the simulation:**
1. Replace the line with your relevant path - <path_to_USPS_package_on_host>:/sim_ws/src/USPS to your volumes field in `src/usps-docker/docker-compose.yml up` for the sim container.
2. Bringup the novnc container and the sim container with docker-compose:
```bash
cd $HOME
docker-compose -f src/usps-docker/docker-compose.yml up
``` 
3. In a separate terminal, run the following, and you'll have the a bash session in the simulation container. `tmux` is available for convenience.
```bash
docker exec -it usps-docker_sim_1 /bin/bash
```
4. In your browser, navigate to [http://localhost:8080/vnc.html](http://localhost:8080/vnc.html), you should see the noVNC logo with the connect button. Click the connect button to connect to the session.

# Launching the Simulation

1. `tmux` is included in the contianer, so you can create multiple bash sessions in the same terminal.
2. To launch the simulation, make sure you source both the ROS2 setup script and the local workspace setup script. Run the following in the bash session from the container:
```bash
$ source /opt/ros/foxy/setup.bash
$ source install/local_setup.bash
$ ros2 launch usps-docker gym_bridge_launch.py
```
A rviz window should pop up showing the simulation either on your host system or in the browser window depending on the display forwarding you chose.

You can then run another node by creating another bash session in `tmux`.

# Configuring the simulation
- The configuration file for the simulation is at `usps-docker/config/sim.yaml`.
- Topic names and namespaces can be configured but is recommended to leave uncahnged.
- The map can be changed via the `map_path` parameter. You'll have to use the full path to the map file in the container. The map follows the ROS convention. It is assumed that the image file and the `yaml` file for the map are in the same directory with the same name. See the note below about mounting a volume to see where to put your map file.
- The `num_agent` parameter can be changed to either 1 or 2 for single or two agent racing.
- The ego and opponent starting pose can also be changed via parameters, these are in the global map coordinate frame.

The entire directory of the repo is mounted to a workspace `/sim_ws/src` as a package. All changes made in the repo on the host system will also reflect in the container. After changing the configuration, run `colcon build` again in the container workspace to make sure the changes are reflected.

# Topics published by the simulation

In **single** agent:

`/scan`: The ego agent's laser scan

`/ego_racecar/odom`: The ego agent's odometry

`/map`: The map of the environment

A `tf` tree is also maintained.

In **two** agents:

In addition to the topics available in the single agent scenario, these topics are also available:

`/opp_scan`: The opponent agent's laser scan

`/ego_racecar/opp_odom`: The opponent agent's odometry for the ego agent's planner

`/opp_racecar/odom`: The opponent agents' odometry

`/opp_racecar/opp_odom`: The ego agent's odometry for the opponent agent's planner

# Topics subscribed by the simulation

In **single** agent:

`/drive`: The ego agent's drive command via `AckermannDriveStamped` messages

`/initalpose`: This is the topic for resetting the ego's pose via RViz's 2D Pose Estimate tool. Do **NOT** publish directly to this topic unless you know what you're doing.

TODO: kb teleop topics

In **two** agents:

In addition to all topics in the single agent scenario, these topics are also available:

`/opp_drive`: The opponent agent's drive command via `AckermannDriveStamped` messages. Note that you'll need to publish to **both** the ego's drive topic and the opponent's drive topic for the cars to move when using 2 agents.

`/goal_pose`: This is the topic for resetting the opponent agent's pose via RViz's 2D Goal Pose tool. Do **NOT** publish directly to this topic unless you know what you're doing.

# Keyboard Teleop

The keyboard teleop node from `teleop_twist_keyboard` is also installed as part of the simulation's dependency. To enable keyboard teleop, set `kb_teleop` to `True` in `sim.yaml`. After launching the simulation, in another terminal, run:
```bash
ros2 run teleop_twist_keyboard teleop_twist_keyboard
```
Then, press `i` to move forward, `u` and `o` to move forward and turn, `,` to move backwards, `m` and `.` to move backwards and turn, and `k` to stop in the terminal window running the teleop node.

# Developing and creating your own agent in ROS 2

There are multiple ways to launch your own agent to control the vehicles.

- The first one is creating a new package for your agent in the `/sim_ws` workspace inside the sim container. After launch the simulation, launch the agent node in another bash session while the sim is running.
- The second one is to create a new ROS 2 container for you agent node. Then create your own package and nodes inside. Launch the sim container and the agent container both. With default networking configurations for `docker`, the behavior is to put The two containers on the same network, and they should be able to discover and talk to each other on different topics. If you're using noVNC, create a new service in `docker-compose.yml` for your agent node. You'll also have to put your container on the same network as the sim and novnc containers.

## Accessing the AWS

# On AWS
1. Sign in using slack email and password.
2. Run `vncserver -geometry 1920x1080 :1`

# On Local
1. Copy awskey.pem into the current directory (usps-docker)
2. `chmod 600 awskey.pem`
3. `chmod +x ./novnc_launch.sh`
4. Change the ip in the `novnc.conf` file to match the aws server ip.
5. Run `./novnc_launch.sh`
6. Go to `localhost:6080/vnc.html`
7. Sign in using vnc password from slack.
