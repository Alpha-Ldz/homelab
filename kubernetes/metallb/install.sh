kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/mode: \"\"/mode: \"ipvs\"" | \
kubectl apply -f - -n kube-system
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
kubectl apply -f ./metallb.yaml

kubectl create namespace nginx-ingress
helm install nginx-ingress oci://ghcr.io/nginx/charts/nginx-ingress --version 0.17.4 --namespace nginx-ingress