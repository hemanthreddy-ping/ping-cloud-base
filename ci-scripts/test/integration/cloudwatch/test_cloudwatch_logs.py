import unittest
import os
import boto3
import json

from pprint import pprint

from kubernetes.client.rest import ApiException
from kubernetes import client, config

aws_region = os.getenv('AWS_REGION', 'us-west-2')
aws_client = boto3.client('logs', region_name=aws_region)

config.load_kube_config()
k8s_client = client.CoreV1Api()

pod_name = "es-cluster-hot-0"
pod_namespace = "elastic-stack-logging"
container_name = "elasticsearch"
k8s_cluster_name = os.getenv('TENANT_NAME')
log_group_name = f"/aws/containerinsights/{k8s_cluster_name}/application"
log_stream_name = f"{pod_name}_{pod_namespace}_{container_name}.cw_out"


def get_latest_cw_logs():
    cw_logs = []
    response = aws_client.get_log_events(
        logGroupName=log_group_name,
        logStreamName=log_stream_name,
        limit=5,
        startFromHead=False
    )

    for event in (response['events']):
        cw_logs.append(json.loads(event['message'])['log'].replace('\n', ''))

    return cw_logs


def get_latest_pod_logs():
    pod_logs = k8s_client.read_namespaced_pod_log(
        name=pod_name,
        container=container_name,
        namespace=pod_namespace,
        tail_lines=5
    )
    pod_logs = pod_logs.splitlines()
    return pod_logs


class TestCloudWatchLogs(unittest.TestCase):
    def test_cloudwatch_log_group_exists(self):
        response = aws_client.describe_log_groups(
            logGroupNamePrefix=log_group_name
        )

        self.assertNotEqual(response['logGroups'], [], "Required log groups not found")

    def test_cloudwatch_log_stream_exists(self):
        response = aws_client.describe_log_streams(
            logGroupName=log_group_name,
            logStreamNamePrefix=log_stream_name
        )

        self.assertNotEqual(response['logStreams'], [], "Required log stream not found")

    def test_cloudwatch_logs_exists(self):
        cw_logs = get_latest_cw_logs()
        self.assertNotEqual(len(cw_logs), 0, "No CW logs found")

    def test_pod_logs_exists(self):
        pod_logs = get_latest_pod_logs()
        self.assertNotEqual(pod_logs, 0, "No pod logs found")

    def test_cw_logs_equal_pod_logs(self):
        cw_logs = get_latest_cw_logs()
        pod_logs = get_latest_pod_logs()
        self.assertEqual(cw_logs, pod_logs, "Logs are not the same")


if __name__ == '__main__':
    unittest.main()
    # get_latest_cw_logs()
    # get_latest_pod_logs()
