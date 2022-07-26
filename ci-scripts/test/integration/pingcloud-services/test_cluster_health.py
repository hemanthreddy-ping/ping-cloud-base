from datetime import datetime
import json
import unittest

import kubernetes.watch
import requests
from kubernetes import client, config


class TestClusterHealth(unittest.TestCase):
    core_client = None
    batch_client = None
    network_client = None
    endpoint = None

    @classmethod
    def setUpClass(cls):
        config.load_kube_config()
        cls.core_client = client.CoreV1Api()
        cls.batch_client = client.BatchV1Api()
        cls.network_client = client.NetworkingV1Api()
        cls.endpoint = cls.get_healthcheck_endpoint()
        cls.run_job("healthcheck-cluster-health")

    @classmethod
    def get_healthcheck_endpoint(cls) -> str:
        response = cls.network_client.list_ingress_for_all_namespaces(
            _preload_content=False
        )
        routes = json.loads(response.data)
        hostname = next(
            (
                route["spec"]["rules"][0]["host"]
                for route in routes["items"]
                if "healthcheck" in route["spec"]["rules"][0]["host"]
            ),
            None,
        )
        return f"http://{hostname}"

    @classmethod
    def run_job(cls, name: str, wait: bool = True) -> client.V1Job:
        cron_jobs = cls.batch_client.list_cron_job_for_all_namespaces()
        try:
            job_body, job_namespace = next((cron_job.spec.job_template, cron_job.metadata.namespace) for cron_job in cron_jobs.items if cron_job.metadata.name == name)
        except StopIteration:
            raise ValueError(f"No cron job named '{name}' found")

        curr_time = datetime.now().strftime("%Y%m%d%H%M%S.%f")
        job_body.metadata.name = f"{name}-test-{curr_time}"
        job = cls.batch_client.create_namespaced_job(body=job_body, namespace=job_namespace)

        if wait:
            cls.wait_for_job_complete(job_body.metadata.name, job_namespace)

        return job

    @classmethod
    def wait_for_job_complete(cls, name: str, namespace: str):
        watch = kubernetes.watch.Watch()
        for event in watch.stream(func=cls.core_client.list_namespaced_pod, namespace=namespace, timeout_seconds=60):
            if event["object"].metadata.name.startswith(name) and event["object"].status.phase in ["Succeeded", "Failed"]:
                watch.stop()
                return

    def test_cluster_health_cron_job_exists(self):
        cron_jobs = self.batch_client.list_cron_job_for_all_namespaces()
        expected_name = "healthcheck-cluster-health"
        cron_job_name = next((cron_job.metadata.name for cron_job in cron_jobs.items if cron_job.metadata.name == expected_name), "")
        self.assertEqual(expected_name, cron_job_name, f"Cron job '{expected_name}' not found in cluster")

    def test_health_check_has_cluster_health_results(self):
        res = requests.get(self.endpoint, verify=False)
        self.assertTrue("cluster-health" in res.json()["health"].keys(), "No cluster health in health check results")

    def test_health_check_has_namespace_results(self):
        res = requests.get(self.endpoint, verify=False)
        res = [key for key in res.json()["health"]["cluster-health"]["tests"]["cluster-members"] if "namespace" in key]
        self.assertTrue(len(res) > 0, "No namespace checks found in health check results")

    def test_health_check_has_node_results(self):
        res = requests.get(self.endpoint, verify=False)
        res = [key for key in res.json()["health"]["cluster-health"]["tests"]["cluster-members"] if "node" in key]
        self.assertTrue(len(res) > 0, "No node checks found in health check results")

    def test_health_check_has_stateful_set_results(self):
        res = requests.get(self.endpoint, verify=False)
        res = [key for key in res.json()["health"]["cluster-health"]["tests"]["cluster-members"] if "statefulset" in key]
        self.assertTrue(len(res) > 0, "No statefulset checks found in health check results")


if __name__ == "__main__":
    unittest.main()
