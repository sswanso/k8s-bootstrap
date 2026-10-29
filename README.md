# k8s-bootstrap

Initial bootstrap scripts for setting up a Kubernetes workshop environment.

- `Setup-WSL2-Windows11.ps1`: enables WSL 2 and installs an Ubuntu distro on Windows 11 (see `Setup-WSL2-Windows11.readme.md`).
- `install_docker_kind.sh`: installs Docker and kind inside the Linux environment.

# Required Environment

## Windows
- 	Ubuntu 26.04 virtual system 
- - If you are using Windows 11, we recommend using WSL2.
-	Internet access from within the Ubuntu environment.
-	(installed by our script) Kind (Kubernetes in Docker) installed and operational within the Ubuntu environment.
-	(installed by our script) Kubectl installed in your Ubuntu environment (https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)

## Macs and Linux
 - Internet Access
 - Kind installed and operational (https://kind.sigs.k8s.io/docs/user/quick-start/)
 - Kubectl installed in your command line environment (https://kubernetes.io/docs/tasks/tools/install-kubectl-macos)

# Installation Steps

## Windows 
- Follow the instructions in `Setup-WSL2-Windows11.readme.md` to set up your Ubuntu instance
- Use the script in `install_docker_kind.sh` inside your WSL instance to configure your container environment
- Run `sudo --preserve-env=http_proxy,https_proxy,no_proxy kind create cluster`
- To verify, run these commands:
- -  `sudo kubectl get nodes`: verify there is nothing that says NotReady
- -  `sudo kubectl get pods -A`: verify everything is Running
- -  `sudo kubectl run --image=nginx nginx; sudo kubectl get pods`: verify the nginx pod is Running
- After verification, you can delete the testing pod: `sudo kubectl delete pods nginx`

---
Please reach out to us if you have any problems! We're happy to help
