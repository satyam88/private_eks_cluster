
#!/bin/bash

kubectl get nodes -o custom-columns=NAME:.metadata.name,INTERNAL-IP:.status.addresses[?\(@.type==\"InternalIP\"\)].address --no-headers