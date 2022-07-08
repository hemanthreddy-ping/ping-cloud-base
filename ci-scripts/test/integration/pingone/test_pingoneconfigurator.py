import json
import unittest

import requests
from kubernetes import client, config


class TestPingOneConfigurator(unittest.TestCase):
    core_client = None

    @classmethod
    def setUpClass(cls):
        config.load_kube_config()
        cls.core_client = client.CoreV1Api()

    def setUp(self):
        self.endpoint = self.get_pingoneconfigurator_endpoint()

    def get_pingoneconfigurator_endpoint(self) -> str:
        response = self.network_client.list_ingress_for_all_namespaces(
            _preload_content=False
        )
        routes = json.loads(response.data)
        hostname = next(
            (
                route["spec"]["rules"][0]["host"]
                for route in routes["items"]
                if "pingoneconfigurator" in route["spec"]["rules"][0]["host"]
            ),
            None,
        )
        return f"http://{hostname}"       

    def test_pingoneconfigurator_pod_exists(self):
        pods = self.core_client.list_pod_for_all_namespaces(watch=False)
        res = next(
            (
                pod.metadata.name
                for pod in pods.items
                if pod.metadata.name.startswith("pingone-configurator")
            ),
            False,
        )
        self.assertTrue(res)
    
    def test_pingoneconfigurator_get_route_ok_response(self):
        res = requests.get(self.endpoint, verify=False)
        self.assertEqual(200, res.status_code)
        
if __name__ == "__main__":
    unittest.main()
