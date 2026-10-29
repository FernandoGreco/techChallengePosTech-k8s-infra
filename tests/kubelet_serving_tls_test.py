import base64
import copy
import importlib.util
from pathlib import Path
import sys
import types
import unittest
from unittest.mock import patch

# CSR validation does not use YAML; keep these unit tests dependency-free.
sys.modules.setdefault("yaml", types.ModuleType("yaml"))
location = Path(__file__).resolve().parents[1] / "scripts" / "kubelet-serving-tls.py"
spec = importlib.util.spec_from_file_location("serving_tls", location)
tls = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tls)


class ServingCsrSafetyTests(unittest.TestCase):
    def setUp(self):
        self.request = {"spec": {
            "signerName": "kubernetes.io/kubelet-serving", "username": "system:node:node-a",
            "groups": ["system:nodes", "system:authenticated"],
            "usages": ["digital signature", "key encipherment", "server auth"],
            "request": base64.b64encode(b"unit-test-placeholder-not-a-real-csr").decode(),
        }}

    def parsed(self, san, subject="subject=CN=system:node:node-a,O=system:nodes"):
        return patch.object(tls, "run", side_effect=["", subject,
                            "X509v3 Subject Alternative Name:\n    " + san + "\n"])

    def test_exact_authenticated_node_and_sans_are_accepted(self):
        with self.parsed("DNS:node-a, IP Address:10.0.0.1"):
            tls.validate_request(self.request, "node-a", "10.0.0.1")

    def test_other_signers_requesters_groups_and_usages_are_rejected(self):
        for key, value in [("signerName", "kubernetes.io/kube-apiserver-client"),
                           ("username", "system:node:node-b"), ("groups", ["system:authenticated"]),
                           ("groups", ["system:nodes", "system:authenticated", "system:masters"]),
                           ("usages", ["server auth", "client auth"])]:
            request = copy.deepcopy(self.request)
            request["spec"][key] = value
            with patch.object(tls, "run") as command:
                with self.assertRaises(RuntimeError):
                    tls.validate_request(request, "node-a", "10.0.0.1")
                command.assert_not_called()

    def test_extra_or_wrong_dns_ip_uri_and_email_are_rejected(self):
        for san in ["DNS:node-a, IP Address:10.0.0.2", "DNS:node-b, IP Address:10.0.0.1",
                    "DNS:node-a, IP Address:10.0.0.1, DNS:kubernetes",
                    "DNS:node-a, IP Address:10.0.0.1, URI:spiffe://untrusted",
                    "DNS:node-a, IP Address:10.0.0.1, email:untrusted@example.invalid"]:
            with self.parsed(san), self.assertRaises(RuntimeError):
                tls.validate_request(self.request, "node-a", "10.0.0.1")

    def test_wrong_subject_and_invalid_signature_are_rejected(self):
        with self.parsed("DNS:node-a, IP Address:10.0.0.1", "subject=CN=system:node:node-b,O=system:nodes"):
            with self.assertRaises(RuntimeError):
                tls.validate_request(self.request, "node-a", "10.0.0.1")
        with patch.object(tls, "run", side_effect=RuntimeError("INVALID_SIGNATURE")):
            with self.assertRaises(RuntimeError):
                tls.validate_request(self.request, "node-a", "10.0.0.1")

    def test_multiline_san_cannot_hide_additional_identities(self):
        with self.parsed("DNS:node-a, IP Address:10.0.0.1,\n    URI:spiffe://untrusted"):
            with self.assertRaises(RuntimeError):
                tls.validate_request(self.request, "node-a", "10.0.0.1")


if __name__ == "__main__":
    unittest.main()
