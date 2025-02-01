kubectl create namespace klipper
kubectl apply -f ./persistentvolume.yaml -n klipper
kubectl apply -f ./persistentvolumeclaim.yaml -n klipper
kubectl apply -f ./klipper-deployment.yaml -n klipper
kubectl apply -f ./mainsail-deployment.yaml -n klipper
