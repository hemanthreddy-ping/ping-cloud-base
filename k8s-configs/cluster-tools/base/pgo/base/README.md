# PGO: The Postgres Operator from Crunchy Data

This directory contains UNMODIFIED manifest yamls. They are copied directly from the `./kustomize/install` directory
in this repository:
https://github.com/CrunchyData/postgres-operator-examples

ALL directories/files are copied here, even if they are unused. The only portion of this directory that is Ping-specific
is the top-level kustomization.yaml and this README.md.

# Update this when you update this directory based on the postgres-operator-examples repo.
# TODO: improve the process so it's less manual
The specific commit it's referenced against is:
https://github.com/CrunchyData/postgres-operator-examples/tree/c35b44b9bcabe6c1fea896bde043ff0e2d4bb43e

# TODO: as of right now, some of these manifest files are unused.

# Updated Crunchy Data images to our own ECR images
name: postgres-operator
current image: registry.developers.crunchydata.com/crunchydata/postgres-operator:ubi8-5.1.3-0
updated image: public.ecr.aws/r2h3l6e4/pingcloud-clustertools/crunchydata/postgres-operator:ubi8-5.1.3-0

name: postgres-operator-upgrade
current image: registry.developers.crunchydata.com/crunchydata/postgres-operator-upgrade:ubi8-5.1.3-0
updated image: public.ecr.aws/r2h3l6e4/pingcloud-clustertools/crunchydata/postgres-operator-upgrade:ubi8-5.1.3-0

name: crunchy-upgrade
current image: registry.developers.crunchydata.com/crunchydata/crunchy-upgrade:ubi8-5.1.3-0
updated image: public.ecr.aws/r2h3l6e4/pingcloud-clustertools/crunchydata/crunchy-upgrade:ubi8-5.1.3-0

name: crunchy-postgres
current image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres:ubi8-13.8-0
updated image: public.ecr.aws/r2h3l6e4/pingcloud-clustertools/crunchydata/crunchy-postgres:ubi8-13.8-0
current image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres:ubi8-14.5-0
updated image: public.ecr.aws/r2h3l6e4/pingcloud-clustertools/crunchydata/crunchy-postgres:ubi8-14.5-0

name: crunchy-postgres-gis
current image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-13.8-3.0-0
updated image: public.ecr.aws/r2h3l6e4/pingcloud-clustertools/crunchydata/crunchy-postgres-gis:ubi8-13.8-3.0-0
current image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-13.8-3.1-0
updated image: public.ecr.aws/r2h3l6e4/pingcloud-clustertools/crunchydata/crunchy-postgres-gis:ubi8-13.8-3.1-0
current image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-14.5-3.1-0
updated image: public.ecr.aws/r2h3l6e4/pingcloud-clustertools/crunchydata/crunchy-postgres-gis:ubi8-14.5-3.1-0
current image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres-gis:ubi8-14.5-3.2-0
updated image: public.ecr.aws/r2h3l6e4/pingcloud-clustertools/crunchydata/crunchy-postgres-gis:ubi8-14.5-3.2-0

name: crunchy-pgadmin4
current image: registry.developers.crunchydata.com/crunchydata/crunchy-pgadmin4:ubi8-4.30-3
updated image: public.ecr.aws/r2h3l6e4/pingcloud-clustertools/crunchydata/crunchy-pgadmin4:ubi8-4.30-3

name: crunchy-pgbackrest
current image: registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest:ubi8-2.40-0
updated image: public.ecr.aws/r2h3l6e4/pingcloud-clustertools/crunchydata/crunchy-pgbackrest:ubi8-2.40-0

name: crunchy-pgbouncer
current image: registry.developers.crunchydata.com/crunchydata/crunchy-pgbouncer:ubi8-1.17-0
updated image: public.ecr.aws/r2h3l6e4/pingcloud-clustertools/crunchydata/crunchy-pgbouncer:ubi8-1.17-0

name: crunchy-postgres-exporter
current image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres-exporter:ubi8-5.1.3-0
updated image: public.ecr.aws/r2h3l6e4/pingcloud-clustertools/crunchydata/crunchy-postgres-exporter:ubi8-5.1.3-0
current image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres-exporter:ubi8-5.2.0-0
updated image: public.ecr.aws/r2h3l6e4/pingcloud-clustertools/crunchydata/crunchy-postgres-exporter:ubi8-5.2.0-0
