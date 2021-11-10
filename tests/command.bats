#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

#export MKTEMP_STUB_DEBUG=/dev/tty
#export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty
#export AWS_STUB_DEBUG=/dev/tty
#export TAR_STUB_DEBUG=/dev/tty
#export DOCKER_STUB_DEBUG=/dev/tty

@test "Builds an image when service is specified" {
  export BUILDKITE_PLUGIN_DOCKER_CACHE_METADATA_KEY=metadata_key
  export BUILDKITE_PLUGIN_DOCKER_CACHE_S3_BUCKET=example-bucket
  export BUILDKITE_PLUGIN_DOCKER_CACHE_S3_KEY=example-key
  export BUILDKITE_PLUGIN_DOCKER_CACHE_SERVICE=service
  export BUILDKITE_PIPELINE_SLUG="slug"
  export BUILDKITE_JOB_ID="1"
  export temp_dir="$(mktemp -d)"
  export BUILDKITE_COMMIT="abcdef"
  touch ${temp_dir}/remote_cache.tar.gz

  stub mktemp \
    "-d : echo ${temp_dir}"
  stub buildkite-agent \
    "meta-data exists $BUILDKITE_PLUGIN_DOCKER_CACHE_METADATA_KEY : exit 1"

  stub aws \
    "s3 cp --quiet s3://${BUILDKITE_PLUGIN_DOCKER_CACHE_S3_BUCKET}/${BUILDKITE_PIPELINE_SLUG}/latest ${temp_dir}/remote_cache.tar.gz : echo" \
    "s3 cp --quiet ${temp_dir}/local_cache.tar.gz s3://${BUILDKITE_PLUGIN_DOCKER_CACHE_S3_BUCKET}/${BUILDKITE_PLUGIN_DOCKER_CACHE_S3_KEY} : echo"

  stub tar \
    "-xzf ${temp_dir}/remote_cache.tar.gz -C ${temp_dir}/remote : echo" \
    "-czf ${temp_dir}/local_cache.tar.gz ./ : echo"
  
  stub docker \
    "buildx create --driver docker-container --name slug-1 : echo" \
    "buildx bake -f docker-compose.yml --progress plain \
    --builder slug-1 \
    --set=service.cache-to=type=local,dest=${temp_dir}/local,mode=max \
    --set=\*.cache-from=type=local\,src=${temp_dir}/remote service : echo" \
    "buildx rm slug-1 : echo"
  run "$PWD/hooks/command"

  assert_success

  unstub mktemp
  unstub buildkite-agent
  unstub aws
  unstub tar
  unstub docker
}

@test "Copies an existing image when no service is specified" {
  export BUILDKITE_PLUGIN_DOCKER_CACHE_METADATA_KEY=metadata_key
  export BUILDKITE_PLUGIN_DOCKER_CACHE_S3_BUCKET=example-bucket
  export BUILDKITE_PLUGIN_DOCKER_CACHE_S3_KEY=example-key
  export BUILDKITE_PIPELINE_SLUG="slug"
  export BUILDKITE_JOB_ID="1"
  export temp_dir="$(mktemp -d)"
  export BUILDKITE_COMMIT="abcdef"
  touch ${temp_dir}/remote_cache.tar.gz

  stub mktemp \
    "-d : echo ${temp_dir}"
  stub buildkite-agent \
    "meta-data exists $BUILDKITE_PLUGIN_DOCKER_CACHE_METADATA_KEY : echo \"cache_key\""
  
  stub aws \
    "s3 cp --quiet s3://${BUILDKITE_PLUGIN_DOCKER_CACHE_S3_BUCKET}/${BUILDKITE_PIPELINE_SLUG}/cache_key ${temp_dir}/remote_cache.tar.gz : echo" \
    "s3 cp --quiet ${temp_dir}/local_cache.tar.gz s3://${BUILDKITE_PLUGIN_DOCKER_CACHE_S3_BUCKET}/${BUILDKITE_PLUGIN_DOCKER_CACHE_S3_KEY} : echo"
  
  stub tar \
    "-xzf ${temp_dir}/remote_cache.tar.gz -C ${temp_dir}/remote : echo"

  stub mv \
    "${temp_dir}/remote_cache.tar.gz ${temp_dir}/local_cache.tar.gz : echo"
}
