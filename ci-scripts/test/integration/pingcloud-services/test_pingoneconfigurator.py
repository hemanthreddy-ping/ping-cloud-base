import unittest

from kubernetes import client, config


class TestPingOneConfigurator(unittest.TestCase):
    core_client = None

    @classmethod
    def setUpClass(cls):
        config.load_kube_config()
        cls.core_client = client.CoreV1Api()
      

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

    def test_pingoneconfigurator_pod_complete(self):
        pods = self.core_client.list_pod_for_all_namespaces(watch=False)
        container_statuses = next(
            (
                pod.status.container_statuses
                for pod in pods.items
                if pod.metadata.name.startswith("pingone-configurator")
            ),
            False,
            
        )
        res = next(
            (
                container.state.terminated.reason
                for container in container_statuses
                if container.name.startswith("pingone-configurator")
            ),
            False,
        )
        self.assertEquals("Completed",res)
    
        
if __name__ == "__main__":
    unittest.main()
