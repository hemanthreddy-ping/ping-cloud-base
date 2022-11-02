import json
import unittest
import os
import boto3

from datetime import datetime

import kubernetes as k8s


class K8sUtils(unittest.TestCase):
    """
    Base class for Healthcheck test suites

    Sets up basic kubernetes API clients and helper methods
    """

    batch_client = None
    core_client = None
    network_client = None
    endpoint = None

    aws_region = os.getenv("AWS_REGION", "us-west-2")
    aws_client = boto3.client("logs", region_name=aws_region)

    pod_name = None
    pod_namespace = None
    container_name = None
    k8s_cluster_name = None
    log_group_name = None
    log_stream_name = None
    log_lines = None

    @classmethod
    def setUpClass(cls):
        k8s.config.load_kube_config()
        cls.batch_client = k8s.client.BatchV1Api()
        cls.core_client = k8s.client.CoreV1Api()
        cls.network_client = k8s.client.NetworkingV1Api()
        cls.endpoint = cls.get_endpoint("healthcheck")

    @classmethod
    def get_endpoint(cls, substring: str) -> str:
        response = cls.network_client.list_ingress_for_all_namespaces(
            _preload_content=False
        )
        routes = json.loads(response.data)
        hostname = next(
            (
                route["spec"]["rules"][0]["host"]
                for route in routes["items"]
                if substring in route["spec"]["rules"][0]["host"]
            ),
            None,
        )
        return f"http://{hostname}"

    @classmethod
    def run_job(cls, name: str, wait: bool = True) -> k8s.client.V1Job:
        cron_jobs = cls.batch_client.list_cron_job_for_all_namespaces()
        try:
            job_body, job_namespace = next(
                (cron_job.spec.job_template, cron_job.metadata.namespace)
                for cron_job in cron_jobs.items
                if cron_job.metadata.name == name
            )
        except StopIteration:
            raise ValueError(f"No cron job named '{name}' found")

        curr_time = datetime.now().strftime("%Y%m%d%H%M%S.%f")
        job_body.metadata.name = f"{name}-test-{curr_time}"
        job = cls.batch_client.create_namespaced_job(
            body=job_body, namespace=job_namespace
        )

        if wait:
            cls.wait_for_job_complete(job_body.metadata.name, job_namespace)

        return job

    @classmethod
    def wait_for_job_complete(cls, name: str, namespace: str):
        watch = k8s.watch.Watch()
        for event in watch.stream(
            func=cls.core_client.list_namespaced_pod,
            namespace=namespace,
            timeout_seconds=60,
        ):
            if event["object"].metadata.name.startswith(name) and event[
                "object"
            ].status.phase in ["Succeeded", "Failed"]:
                watch.stop()
                return

    def get_latest_cw_logs(self):
        cw_logs = []
        response = self.aws_client.get_log_events(
            logGroupName=self.log_group_name,
            logStreamName=self.log_stream_name,
            limit=int(self.log_lines),
            startFromHead=False,
        )

        for event in response["events"]:
            cw_logs.append(json.loads(event["message"])["log"].replace("\n", ""))

        return cw_logs

    def get_latest_pod_logs(self):
        pod_logs = self.core_client.read_namespaced_pod_log(
            name=self.pod_name, container=self.container_name, namespace=self.pod_namespace, tail_lines=int(self.log_lines)
        )
        pod_logs = pod_logs.splitlines()
        return pod_logs
