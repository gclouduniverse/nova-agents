#!/bin/bash -v
export GCS_BUCKET=gs://nova-artifacts-$(gcloud config get-value project)
export ZONE=$(gcloud config get-value compute/zone)
if [[ ZONE == "(unset)" ]]; then
  INSTANCE_ZONE="/"$(curl http://metadata.google.internal/computeMetadata/v1/instance/zone -H "Metadata-Flavor: Google")
  INSTANCE_ZONE="${INSTANCE_ZONE##/*/}"
fi

gsutil ls ${GCS_BUCKET} ||  gsutil mb ${GCS_BUCKET}

gsutil ls ${GCS_BUCKET}/jobs ||  gsutil mkdir $GCS_BUCKET/jobs

cd /home/jupyter
ls jobs || mkdir jobs

function get-job-yaml-val() {
  export key=$1:
  export val=$(grep ${key} "jobs/$2.yaml")
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

while :
do
  sleep 5
  ls jobs/*.yaml || continue
  echo "Jobs found."
  for job in jobs/*.yaml
  do
    export job=${job:5:-5}
    echo "Processing job ${job}"
    gsutil ls ${GCS_BUCKET}/jobs/${job}
    if [[ "$?" != "0" ]]; then
      echo "Creating job ${job}"
      export gput=$(get-job-yaml-val gpu_type ${job})
      echo $gput
      export gpuc=$(get-job-yaml-val gpu_count ${job})
      echo $gpuc
      export mcount=$(get-job-yaml-val machine_count ${job})
      echo $mcount
      export dir=$(get-job-yaml-val dir ${job})
      echo $dir
      export mtype=$(get-job-yaml-val machine_type ${job})
      echo $mtype
      gsutil mkdir $GCS_BUCKET/jobs/$job
      for i in $(seq 1 1 $mcount); do
        export machine=$job$i
        echo "Creating VM: $machine"
        gcloud compute instances create $machine \
          --zone=$(gcloud config get-value compute/zone) \
          --image-family=$(get-image) \
          --image-project=deeplearning-platform-release \
          --maintenance-policy=TERMINATE \
          --accelerator="type=$gput,count=$gpuc"\
          --machine-type=$mtype \
          --boot-disk-size=200GB \
          --scopes=https://www.googleapis.com/auth/cloud-platform

        export machine_dir=$GCS_BUCKET/jobs/$job/$machine
        gsutil mkdir $machine_dir
        gsutil cp -r $dir $machine_dir/$(basename $dir)
        gsutil cp jobs/$job.yaml $machine_dir/$job.yaml
      done
    fi
  done
done
