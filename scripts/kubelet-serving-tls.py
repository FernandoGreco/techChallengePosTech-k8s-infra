#!/usr/bin/env python3
"""Explicit post-Apply TLS operations; never approve unrelated node CSRs."""
import base64
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import urllib.request

import yaml

KUBECTL = ["kubectl", "--kubeconfig=/etc/kubernetes/admin.conf", "--request-timeout=15s"]
CA = Path("/etc/kubernetes/pki/ca.crt")


def run(args, data=None, timeout=30):
    result = subprocess.run(args, input=data, text=True, capture_output=True,
                            timeout=timeout, check=False)
    if result.returncode:
        # Arguments/stdin can contain a Secret or certificate; do not echo them.
        raise RuntimeError("COMMAND_FAILED_" + Path(args[0]).name.upper())
    return result.stdout


def kube(args, data=None, timeout=30):
    return run(KUBECTL + args, data, timeout)


def emit(**values):
    print(json.dumps(values), flush=True)


def configure_cluster():
    cm = json.loads(kube(["-n", "kube-system", "get", "configmap", "kubelet-config", "-o", "json"]))
    config = yaml.safe_load(cm["data"]["kubelet"])
    if config.get("kind") != "KubeletConfiguration":
        raise RuntimeError("UNEXPECTED_KUBELET_CONFIG")
    changed = config.get("serverTLSBootstrap") is not True
    if changed:
        config["serverTLSBootstrap"] = True
        patch = {"data": {"kubelet": yaml.safe_dump(config, sort_keys=False)}}
        kube(["-n", "kube-system", "patch", "configmap", "kubelet-config",
              "--type=merge", "--patch-file=/dev/stdin"], json.dumps(patch))
    emit(clusterServingBootstrap=True, changed=changed)


def enable_node():
    location = Path("/var/lib/kubelet/config.yaml")
    config = yaml.safe_load(location.read_text())
    if config.get("kind") != "KubeletConfiguration":
        raise RuntimeError("UNEXPECTED_NODE_KUBELET_CONFIG")
    if config.get("tlsCertFile") or config.get("tlsPrivateKeyFile"):
        raise RuntimeError("EXISTING_STATIC_KUBELET_TLS_REQUIRES_REVIEW")
    changed = config.get("serverTLSBootstrap") is not True
    if changed:
        config["serverTLSBootstrap"] = True
        location.write_text(yaml.safe_dump(config, sort_keys=False))
        run(["systemctl", "restart", "kubelet"])
    emit(nodeServingBootstrap=True, changed=changed)


def validate_request(csr, node, address):
    spec = csr["spec"]
    if spec.get("signerName") != "kubernetes.io/kubelet-serving":
        raise RuntimeError("WRONG_CSR_SIGNER")
    if spec.get("username") != "system:node:" + node or set(spec.get("groups", [])) != {"system:nodes", "system:authenticated"}:
        raise RuntimeError("WRONG_CSR_REQUESTER")
    usages = set(spec.get("usages", []))
    if not {"digital signature", "server auth"} <= usages or not usages <= {"digital signature", "server auth", "key encipherment"}:
        raise RuntimeError("WRONG_CSR_USAGES")
    request = base64.b64decode(spec["request"], validate=True).decode("ascii")
    run(["openssl", "req", "-verify", "-noout"], request)
    subject = run(["openssl", "req", "-noout", "-subject", "-nameopt", "RFC2253"], request).strip()
    fields = subject.removeprefix("subject=").split(",")
    if len(fields) != 2 or set(fields) != {"O=system:nodes", "CN=system:node:" + node}:
        raise RuntimeError("WRONG_CSR_SUBJECT")
    text = run(["openssl", "req", "-noout", "-text"], request)
    lines = text.splitlines()
    headers = [(index, len(line) - len(line.lstrip())) for index, line in enumerate(lines)
               if re.fullmatch(r"\s*X509v3 Subject Alternative Name:\s*", line)]
    if len(headers) != 1:
        raise RuntimeError("CSR_WITHOUT_SAN")
    index, indentation = headers[0]
    content = []
    for line in lines[index + 1:]:
        if line.strip() and len(line) - len(line.lstrip()) <= indentation:
            break
        if line.strip():
            content.append(line.strip())
    alternatives = [part.strip() for part in " ".join(content).split(",")]
    if len(alternatives) != 2 or set(alternatives) != {"DNS:" + node, "IP Address:" + str(ipaddress.ip_address(address))}:
        raise RuntimeError("UNEXPECTED_CSR_SAN")


def approve(expected):
    # Require the API inventory to agree with the operator's AWS-verified mapping.
    inventory = json.loads(kube(["get", "nodes", "-o", "json"]))
    for name, address in expected.items():
        matches = [n for n in inventory["items"] if n["metadata"]["name"] == name]
        if len(matches) != 1 or not any(a["type"] == "InternalIP" and a["address"] == address
                                      for a in matches[0]["status"]["addresses"]):
            raise RuntimeError("NODE_ADDRESS_MAPPING_MISMATCH")
    complete = set()
    for _ in range(30):
        csrs = json.loads(kube(["get", "csr", "-o", "json"]))["items"]
        for csr in csrs:
            spec = csr["spec"]
            name = spec.get("username", "").removeprefix("system:node:")
            if name not in expected or spec.get("signerName") != "kubernetes.io/kubelet-serving":
                continue
            conditions = {c["type"] for c in csr.get("status", {}).get("conditions", [])}
            if conditions & {"Denied", "Failed"}:
                continue
            validate_request(csr, name, expected[name])
            if "Approved" not in conditions:
                kube(["certificate", "approve", csr["metadata"]["name"]])
                emit(servingCsrApproved=csr["metadata"]["name"], node=name, validatedSubjectAndSan=True)
            if csr.get("status", {}).get("certificate"):
                complete.add(name)
        if complete == set(expected):
            emit(servingCertificatesIssued=len(complete), unrelatedCsrsApproved=0)
            return
        time.sleep(3)
    raise RuntimeError("SERVING_CERTIFICATE_ISSUANCE_TIMEOUT")


def install_metrics():
    os.umask(0o077)
    root = Path("/etc/kubernetes/pki/tc3-metrics-server")
    if root.is_symlink():
        raise RuntimeError("UNSAFE_TLS_DIRECTORY")
    root.mkdir(mode=0o700, exist_ok=True)
    cert, key = root / "tls.crt", root / "tls.key"
    reusable = cert.is_file() and key.is_file()
    if reusable:
        reusable = subprocess.run(["openssl", "x509", "-in", str(cert), "-noout", "-checkend", "2592000"],
                                  capture_output=True, check=False).returncode == 0
    if not reusable:
        csr, extensions = root / "request.csr", root / "extensions.cnf"
        extensions.write_text("basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\nsubjectAltName=DNS:metrics-server,DNS:metrics-server.kube-system,DNS:metrics-server.kube-system.svc,DNS:metrics-server.kube-system.svc.cluster.local\n")
        run(["openssl", "req", "-new", "-newkey", "rsa:2048", "-nodes", "-keyout", str(key),
             "-out", str(csr), "-subj", "/CN=metrics-server.kube-system.svc"])
        run(["openssl", "x509", "-req", "-in", str(csr), "-CA", str(CA),
             "-CAkey", "/etc/kubernetes/pki/ca.key", "-set_serial", "0x" + os.urandom(16).hex(),
             "-days", "365", "-sha256", "-extfile", str(extensions), "-out", str(cert)])
        csr.unlink()
        extensions.unlink()
    run(["openssl", "verify", "-CAfile", str(CA), "-purpose", "sslserver",
         "-verify_hostname", "metrics-server.kube-system.svc", str(cert)])
    key.chmod(0o600)
    ca = base64.b64encode(CA.read_bytes()).decode("ascii")
    secret = {"apiVersion": "v1", "kind": "Secret", "metadata": {"name": "metrics-server-serving-tls", "namespace": "kube-system"},
              "type": "kubernetes.io/tls", "data": {"tls.crt": base64.b64encode(cert.read_bytes()).decode("ascii"),
                                                   "tls.key": base64.b64encode(key.read_bytes()).decode("ascii")}}
    public_ca = {"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "metrics-server-kubelet-ca", "namespace": "kube-system"},
                 "data": {"ca.crt": CA.read_text()}}
    url = "https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.8.0/components.yaml"
    with urllib.request.urlopen(url, timeout=30) as response:
        upstream = response.read().decode("utf-8")
    resources = list(yaml.safe_load_all(upstream))
    for item in resources:
        if item["kind"] == "Deployment":
            pod = item["spec"]["template"]
            pod.setdefault("metadata", {}).setdefault("annotations", {})["tc3.fiappostech/tls-certificate"] = hashlib.sha256(cert.read_bytes()).hexdigest()
            pod["spec"].setdefault("securityContext", {})["fsGroup"] = 1000
            pod["spec"]["volumes"] += [
                {"name": "serving-tls", "secret": {"secretName": "metrics-server-serving-tls", "defaultMode": 0o440}},
                {"name": "kubelet-ca", "configMap": {"name": "metrics-server-kubelet-ca"}}]
            container = pod["spec"]["containers"][0]
            replace = ("--kubelet-preferred-address-types", "--kubelet-certificate-authority", "--tls-cert-file", "--tls-private-key-file", "--kubelet-insecure-tls")
            container["args"] = [a for a in container["args"] if not a.startswith(replace)] + [
                "--kubelet-preferred-address-types=InternalIP,Hostname",
                "--kubelet-certificate-authority=/etc/kubelet-ca/ca.crt",
                "--tls-cert-file=/etc/serving-tls/tls.crt", "--tls-private-key-file=/etc/serving-tls/tls.key"]
            container["volumeMounts"] += [{"name": "serving-tls", "mountPath": "/etc/serving-tls", "readOnly": True},
                                          {"name": "kubelet-ca", "mountPath": "/etc/kubelet-ca", "readOnly": True}]
            container["resources"]["limits"] = {"cpu": "250m", "memory": "300Mi"}
        elif item["kind"] == "APIService":
            item["spec"]["insecureSkipTLSVerify"] = False
            item["spec"]["caBundle"] = ca
    # Secret contents and rendered manifests never reach stdout, argv or logs.
    kube(["apply", "-f", "-"], json.dumps({"apiVersion": "v1", "kind": "List", "items": [secret, public_ca] + resources}))
    emit(metricsServer="v0.8.0", kubeletCertificateVerification=True, aggregationCertificateVerification=True,
         servingCertificateRenewed=not reusable, upstreamManifestSha256=hashlib.sha256(upstream.encode()).hexdigest())


if __name__ == "__main__":
    try:
        action = sys.argv[1]
        if action != "enable-node" and kube(["config", "current-context"]).strip() != "kubernetes-admin@kubernetes":
            raise RuntimeError("UNEXPECTED_KUBERNETES_CONTEXT")
        if action == "configure-cluster":
            configure_cluster()
        elif action == "enable-node":
            enable_node()
        elif action == "approve":
            approve(json.loads(sys.argv[2]))
        elif action == "install-metrics":
            install_metrics()
        else:
            raise RuntimeError("UNKNOWN_TLS_OPERATION")
    except Exception as error:
        emit(result="FAILED", stage=str(error) if re.fullmatch(r"[A-Z0-9_]+", str(error)) else type(error).__name__)
        sys.exit(1)
