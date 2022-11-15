# Docker Deployment 5
November 15, 2022

By: Kingman Tam- Kura Labs

## Purpose:

To deploy a containerized Flask Application using Docker, Terraform, and Amazon ECS

Previously, applications were hosted on EC2's that were either manually set up, or set up with Terraform. Though using this architecture has worked, it has its limitations. Virtual machines require their own operating system to run. This means that it also requires a finite amount of system resources (RAM, CPU, Disk Space, etc) be reserved for its use. When said resources are used up, the system fails. To make matters worse, configuration drift may make running the same application on different operating systems difficult. The use of containers solves both of these problems and more by isolating the application and its dependencies so that it can operate in any environment and use the main systems resources as needed.

## Steps:

### 1. Launch an EC2 with Jenkins installed and activated

- Jenkins is the main tool used in this deployment for pulling the program from the GitHub repository, then building, testing, and deploying it to a server.
- The Jenkins EC2 from previous deployments is used. It is on the default VPC that AWS provides

### 2. Launch an EC2 with Docker installed

- Each of the tools used in this deployment were separated into different EC2s.
  - This was less strenuous on each of the instances (limited resources) and also provided added security on account that unwelcome access to one of the servers would be isolated from all of the other services.
- Packages are installed to allow apt to access repositories over http
  - `sudo apt-get update && sudo apt-get install ca-certificates curl gnupg lsb-release`
- Dockers GPG keys are downloaded to the local machine
  - `sudo mkdir -p /etc/apt/keyrings && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg`
- Dockers repository is established
  - `echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb\_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list \> /dev/null`
- Repositories are updated
  - `sudo apt-get update`
- Docker , Containerd, and DockerCompose is installed
  - `sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin`

### 3. Launch an EC2 with Terraform installed

- For the same reason that Docker is installed onto its own EC2, Terraform too is installed onto its own instance.
- Terraform keyrings are downloaded and saved to the local machine
  - `wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg`
- Terraform repository is established
  - `echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb\_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list`
- Repositories are updated and Terraform is installed
  - `sudo apt update && sudo apt install terraform`

### 4. Create dockerfile

- In order for ECS to launch a container with the most up to date version of the application, the image that the container is imposed onto must have the latest application files.
- For this to be done, a dockerfile (set of instructions that Docker uses to create images) is created that would pull the application files from a GitHub repository to be used.
  - `RUN apt -y install git`
  - `RUN git clone https://github.com/KingmanT/Flask\_Application-Containerized\_Deployment.git`
- After cloning the GitHub repository, GUnicorn is installed and the command to launch GUnicorn is set as an ENTRYPOINT.
  - `RUN pip install gunicorn`
  - `ENTRYPOINT ["python3", "-m", "gunicorn", "-w", "4", "application:app", "-b", "0.0.0.0"]`
  - ENTRYPOINT will set a command that runs when the container is launched.
    - In this case, the ENTRYPOINT command will launch GUnicorn once the container is created.
      - ENTRYPOINT is used instead of CMD because CMD can be overwritten which would cause errors when launching the application.
- For full dockerfile, please find it [HERE](https://github.com/KingmanT/Flask_Application-Containerized_Deployment/blob/main/dockerfile)

### 5. Create Terraform Files

- Terraform is used to create the infrastructure that the container will be launched on.
- The terraform files must include resource blocks for VPC, Subnets, Route Tables, Internet Gateway, Nat Gateway, Elastic IP, Security Groups, Load Balancer, Clusters, ECS service, and Task Definition
  - Task definition must have the DockerHub username and repository of where the image is to be pulled from.
  - Task definition must also have execution and task role ARN from a role that has permissions to perform ECS functions.
- For full Terraform files, please find it [HERE](https://github.com/KingmanT/Flask_Application-Containerized_Deployment/tree/main/intTerraform)

### 6. Create Jenkinsfile

- The Jenkinsfile is used by Jenkins to list out the steps to be taken in the deployment pipeline.
- Steps in the Dockerfile are as follows:
  - Build
    - The Flask environment is built to see if the application can run.
  - Test
    - Unit test is performed to test specific functions in the application
  - Docker\_Build
    - An agent on the Docker EC2 is used to run the commands in this stage
    - The dockerfile is pulled to the workspace using curl
    - The agent logs into DockerHub using credentials set up in Jenkins
    - The image is built using the Dockerfile
    - The new image is pushed to the DockerHub repository that was logged into
  - Terraform Init
    - An agent on the Terraform EC2 is used to carry out Terraform commands
    - Terraform is initialized
  - Terraform Plan
    - Terraform uses the Terraform files to plan out how the architecture needs to be structured and saves the plan to a file called "plan.tfplan".
  - Terraform Apply
    - Terraform uses "plan.tfplan" to create the infrastructure.
- For full Dockerfile, please find it [HERE](https://github.com/KingmanT/Flask_Application-Containerized_Deployment/blob/main/dockerfile)

### 7. Set up Jenkins

- This deployment requires that Jenkins have credentials and agents set up to carry out the stages in the deployment pipeline.
- Agents must be set up using the public IP addresses of the two EC2s: Docker and Terraform.
- Terraform uses AWS services to create infrastructure, so the username and password of a user who has the permissions to do so is saved in Jenkins as secret text that can be called upon in the Jenkinsfile
- DockerHub requires login credentials so that the images can be pushed into a specific repository. The username and password of DockerHub was also saved in Jenkins as secret texts to be used in the Jenkinsfile.

### 8. Build the pipeline

- After everything is set up, the pipeline can be built using Jenkins
  - The most recent code (that is saved to GitHub) is pulled into Jenkins
  - The Docker agent curls the dockerfile from the repository and begins to build a new image
  - As per the Dockerfile, the updated repository (with latest source code) is cloned into the image along with its dependencies and GUnicorn.
  - The image is pushed to DockerHub.
  - Terraform uses the image from DockerHub to create and host the container/application.

## Issues/Troubleshooting:

Setting up the various files individually worked when run manually through the terminal. However, when all of the moving parts are put together into the one pipeline, their compatibility was tested and issues arose.

One of such issues was coordinating the ports that the image was exposing on the container and the ports that are opened in AWS by terraform. On the initial attempt to access the application, a 504 error was produced.

![alt text](https://github.com/KingmanT/Flask_Application-Containerized_Deployment/blob/main/issue%20images/504%20Gateway.JPG)

This was caused by incorrect mapping of the ports in the Terraform file. Originally, the ports were mapped to allow FLASK to be accessed through port 5000 of the container. Unfortunately, the application was not hosted by Flask, but with GUnicorn which hosts the application on port 8000 by default. After modifying the terraform files to reflect this change, the application was able to be accessed through the URL that Amazon ECS provides.

![alt text](https://github.com/KingmanT/Flask_Application-Containerized_Deployment/blob/main/issue%20images/SG%20Ports.JPG)

![alt text](https://github.com/KingmanT/Flask_Application-Containerized_Deployment/blob/main/issue%20images/TG%20ports.JPG)

![alt text](https://github.com/KingmanT/Flask_Application-Containerized_Deployment/blob/main/issue%20images/Task%20Ports.JPG)

## Conclusion:

Many advancements are created in response to issues that the current generation of technology faces. The use of Virtual Machines was a large improvement over hosting applications on dedicated physical machines. It solved many problems but also had several of its own. Containerization created lighter, more portable, and more reliable applications by removing configuration drift from the equation. Many companies would benefit from containerization but as time progresses, more people utilize it, and more issues are found, I'm sure that eventually technology will evolve again and an even more efficient system will take its place.
