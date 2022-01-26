USER=developer
CLUSTER=kubernetes
TOKEN=$(kubectl describe secrets "$(kubectl describe serviceaccount readonlyuser | grep -i Tokens | awk '{print $2}')" | grep token: | awk '{print $2}')

kubectl config set-credentials $USER --token=$TOKEN
kubectl config set-context $USER --cluster=$CLUSTER --user=$USER
kubectl config use-context $USER
