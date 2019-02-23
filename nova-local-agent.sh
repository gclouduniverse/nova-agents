#!/bin/bash -v
source utils.sh

gsutil ls ${GCS_BUCKET} ||  gsutil mb ${GCS_BUCKET}

cd ${JUPYTER_SERVER_ROOT}
[[ -e jobs ]] || mkdir jobs

while :
do
  sleep 5
  ls jobs/*.yaml || continue
  echo "Jobs found."
  for jobfile in jobs/*.yaml
  do
    export job=${jobfile:5:-5}
    echo "Processing job ${job}"
    gsutil ls ${GCS_BUCKET}/jobs/${job}
    if [[ "$?" != "0" ]]; then
      echo "Creating job ${job}"
      export gput=$(get-yaml-val gpu_type ${jobfile})
      echo $gput
      export gpuc=$(get-yaml-val gpu_count ${jobfile})
      echo $gpuc
      export mcount=$(get-yaml-val machine_count ${jobfile})
      echo $mcount
      export dir=$(get-yaml-val dir ${jobfile})
      echo $dir
      ls ${JUPYTER_HOME}/$dir  || continue
      export mtype=$(get-yaml-val machine_type ${jobfile})
      echo $mtype
      export zone=$(get-yaml-val zone ${jobfile})
      [[ -z "$zone" ]] || export ZONE=$zone
      echo $ZONE
      gsutil mkdir $GCS_BUCKET/jobs/$job
      for i in $(seq 1 1 $mcount); do
        export machine=$job$i

        export machine_dir=$GCS_BUCKET/jobs/$job/$machine
        gsutil cp -r $dir/* $machine_dir/homedir/
        gsutil cp jobs/$job.yaml $machine_dir/$job.yaml

        echo "Creating VM: $machine"
        echo "Image: $(get-image)"
        gcloud compute instances create $machine \
          --zone=$ZONE \
          --image-family=$(get-image) \
          --image-project=deeplearning-platform-release \
          --maintenance-policy=TERMINATE \
          --accelerator="type=$gput,count=$gpuc"\
          --machine-type=$mtype \
          --boot-disk-size=200GB \
          --scopes=https://www.googleapis.com/auth/cloud-platform \
          --metadata="post-startup-script=https://raw.githubusercontent.com/gclouduniverse/nova-agents/master/nova-runner-agent.sh"
      done
    fi
  done
done
