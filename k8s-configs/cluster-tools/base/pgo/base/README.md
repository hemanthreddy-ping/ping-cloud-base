# PGO: The Postgres Operator from Crunchy Data

This directory contains PGO manifest files. They are copied directly from the `./kustomize/install` directory in this repository:
https://github.com/CrunchyData/postgres-operator-examples
The only modifications to these files are changes to the image repos from "registry.developers.crunchydata.com" to "public.ecr.aws/r2h3l6e4/pingcloud-clustertools"

ALL directories/files are copied here, even if they are unused. The only portion of this directory that is Ping-specific
is the top-level kustomization.yaml and this README.md.

# Update this when you update this directory based on the postgres-operator-examples repo.
# TODO: improve the process so it's less manual
The specific commit it's referenced against is:
https://github.com/CrunchyData/postgres-operator-examples/tree/c35b44b9bcabe6c1fea896bde043ff0e2d4bb43e

# TODO: as of right now, some of these manifest files are unused.

# Updated Crunchy Data images to our own ECR images

1. Update crunchydata manifests in ping-cluster-tools to the updated image versions for each image.
2. In PCB base directory run, update-pgo.sh script replacing commit_sha variable and example_repo variable with the commit they plan to use 
         (Ex: postgres-operator-examples/tree/c35b44b9bcabe6c1fea896bde043ff0e2d4bb43e)
3. Then git commit, & push.
