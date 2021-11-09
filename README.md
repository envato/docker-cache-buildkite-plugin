# Docker Cache Buildkite Plugin

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) that lets you build docker images suitable for use as a cache in multi-stage builds and stores them in S3.

The current [Docker Compose Plugin](https://github.com/buildkite-plugins/docker-compose-buildkite-plugin) doesn't support building with `buildx` command, which creates images with a cache manifest.
At the time of writing [ECR does not support cache manifests](https://github.com/aws/containers-roadmap/issues/876).

## Example

The following pipeline will retrieve an image from S3 for use as a cache for building an image.
On `main` branch builds it will also push the latest image back to S3.

Setting the metadata key to something compatible with the [Docker Compose Plugin](https://github.com/buildkite-plugins/docker-compose-buildkite-plugin) allows using that plugin for test steps and the pre-built image automatically downloads.

```yml
  - label: ':whale: build ruby container'
    env:
      DOCKER_BUILDKIT: 1
      BUILDKIT_PROGRESS: plain
    plugins:
      - ecr#v1.2.0:
          region: us-east-1
          account-ids: 012345678910
      - docker-cache#v0.0.1:
          s3_bucket: example-bucket
          s3_key: ${BUILDKITE_PIPELINE_SLUG}/${BUILDKITE_COMMIT}
          image_repository: 012345678910.dkr.ecr.us-east-1.amazonaws.com/my-ruby-image
          image_name: ${BUILDKITE_COMMIT}
          # This ensures docker-compose plugin will automatically find the image
          metadata_key: docker-compose-plugin-built-image-tag-ruby
  - wait
  # Do some testing
  - label: ':whale: update image cache'
    branches: main
    env:
      DOCKER_BUILDKIT: 1
      BUILDKIT_PROGRESS: plain
    plugins:
      - ecr#v1.2.0:
          region: us-east-1
          account-ids: 012345678910
      - docker-cache#v0.0.1:
          s3_bucket: example-bucket
          s3_key: ${BUILDKITE_PIPELINE_SLUG}/latest
          metadata_key: docker-cache-image-ruby
```

## Configuration

### `s3_bucket`

The S3 bucket to store images in.

### `s3_key`

The name to give the file we upload to S3.

### `metadata_key`

Where to find/store the s3 key we download the cache image from, using [Buildkite Metadata](https://buildkite.com/docs/agent/v3/cli-meta-data).

### `service` (optional)

The name of the service to build from docker-compose.

### `config` (optional)

The file name of the Docker Compose configuration file to use. Can also be a list of filenames. If `$COMPOSE_FILE` is set, it will be used if `config` is not specified.

Default: `docker-compose.yml`

### `cache_from` (optional)

The name of the s3 location to download a cache from before building.

Default: `${BUILDKITE_PIPELINE_SLUG}/latest`

### `image_repository` (optional)

If present we build an image from the cache and push it to this image repo.

### `image_name` (optional)

The tag we give to the image when pushing to a repo

Default: `${BUILDKITE_COMMIT}`
