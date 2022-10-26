import os
import unittest
import boto3

from kubernetes.client.rest import ApiException
from kubernetes import client, config

aws_region = os.getenv('AWS_REGION')
aws_client = boto3.client('logs', region_name=aws_region)

k8s_config = config.load_kube_config()
k8s_client = client.CoreV1Api()


class TestCloudWatchLogs:
    pass


if __name__ == '__main__':
    unittest.main()
