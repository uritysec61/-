# istio

## Introduction
Istio profiles offer a mechanism to set up and customize the Istio service mesh’s behavior. Istio is an open-source platform that offers capabilities like traffic management, observability, security, and policy enforcement to make managing microservices-based architectures easier. You can customize the behavior of the service mesh to meet your unique needs by defining sets of configuration settings that can be applied to your services using Istio profiles.
  
## Istio Different Profiles
There are different built-in configuration profiles for Istio. The following built-in configuration profiles are currently available:  
  
1. Default  
This enables components according to the default settings of the IstioOperator API. This profile is recommended for production deployments and for primary clusters in a multi-cluster mesh.
  
2. Demo  
This configuration designed to showcase Istio functionality with modest resource requirements. It is suitable to run the Bookinfo application ( Sample application Istio provides — [Build Istio service mesh with Bookinfo application](https://medium.com/@gimhanranasinghe/the-istio-service-mesh-building-service-mesh-on-istio-part-1-8ca060bffc27) ) and associated tasks. This profile enables high levels of tracing and access logging so it is not suitable for performance tests.
  
3. Minimal  
This is same as the default profile, but only the control plane components are installed. This allows you to configure the control plane and data plane components (e.g., gateways) using separate profiles.
  
4. Remote  
This is used for configuring a remote cluster that is managed by an external control plane or by a control plane in a primary cluster of a multi-cluster mesh.
  
5. Empty  
This deploys nothing. This can be useful as a base profile for custom configuration.
  
6. Preview  
The preview profile contains features that are experimental. This is intended to explore new features coming to Istio. Stability, security, and performance are not guaranteed — use at your own risk.


<p align="center">
  <img src="./profile.png" alt="Architecture">
</p>

## “DEMO” Profile vs “DEFAULT” Profile
You can display the profile settings by running the following command.

For Demo Profile settings 

```sh
istioctl profile dump demo 
```

For Default Profile settings 

```sh
istioctl profile dump default
```

According to the above Scenario, if we need to reduce the amount of memory to 150Mi which requests by the istiod component, we can configure it as follows:

```sh
istioctl install --set values.pilot.resources.requests.memory=150Mi
```

## Installation of version-istio

Download the best version.

```sh 
curl -L https://istio.io/downloadIstio | sh -
```

Download to the version you want.

```sh
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.23.2 TARGET_ARCH=x86_64 sh -
```

Set the environment variable path to use isioctl.

```sh
echo "export PATH=$HOME/istio-1.23.2/bin:$PATH" >> .bashrc
source .bashrc
```

check 

```sh
istioctl --help
```

Install the control plane of the isio in the cluster.  
If you install without options, download the default profile with only the isiod and ingress gateway.

```sh 
default profile command : istioctl install
demo profile command : istioctl install --set profile=demo
```

When the installation is complete, you can view the components of the Istio created in the Istio-system namespace.

The isio creates a proxy in each pod for data plane configuration. There are many different ways to generate a proxy, but we will use the method of automatically injecting a proxy container. Labeling the namespace you want to generate a proxy automatically creates a proxy along with the pod generation.

```sh 
kubectl label ns default istio-injection=enabled
```