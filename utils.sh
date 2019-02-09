export JUPYTER_HOME=~/nova
export GCS_BUCKET=gs://nova-artifacts-$(gcloud config get-value project)
export ZONE=$(gcloud config get-value compute/zone)
if [[ ZONE == "(unset)" ]]; then
  ZONE="/"$(curl http://metadata.google.internal/computeMetadata/v1/instance/zone -H "Metadata-Flavor: Google")
  ZONE="${ZONE##/*/}"
fi

function get-yaml-val() {
  export key=$1:
  export val=$(grep ${key} $2)
  echo ${val:${#key}:${#val}}
}

function get-image() {
  hostname | grep pytorch
  if [[ "$?" == "0" ]]; then
    echo pytorch-latest-gpu
  else
    echo tf-latest-gpu
  fi
}

