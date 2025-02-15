kubectl create namespace tigera-operator
helm repo add projectcalico https://docs.tigera.io/calico/charts
helm install calico projectcalico/tigera-operator --version v3.28.0 --namespace tigera-operator