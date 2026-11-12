"""Verify official release material and packages without exposing private credentials."""
import base64
import hashlib
import io
import json
import os
import re
import subprocess
import tempfile
import time
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / ".signing/release"
STUDIO = Path(os.environ.get("DEVECO_STUDIO_HOME", "/Applications/DevEco-Studio.app/Contents"))
JAVA = STUDIO / "jbr/Contents/Home/bin/java"
SIGN_TOOL = STUDIO / "sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar"
BUNDLE = "com.personal.harmonysensorlab"
APP_ID = "6917621347742196774"
PRODUCTS = {"default": (["phone", "tablet"], 50000012), "pc": (["2in1"], 50001013),
            "wearable": (["wearable"], 50100018), "tv": (["tv"], 50101019),
            "multidevice": (["phone", "tablet", "2in1", "wearable"], 50100018)}
# The user approved these first; TV publication follows its separate registration.
FIRST_RELEASE_PRODUCTS = ("default", "pc", "wearable")
PERMISSIONS = {"ohos.permission.ACCELEROMETER", "ohos.permission.GYROSCOPE",
               "ohos.permission.ACTIVITY_MOTION"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def run(arguments, data=None):
    result = subprocess.run(arguments, input=data, capture_output=True, timeout=60)
    require(result.returncode == 0, "Official signing-material verification command failed.")
    return result.stdout


def certificate_public_key(data):
    if b"-----BEGIN CERTIFICATE-----" not in data:
        try:
            data = base64.b64decode(data, validate=True)
        except ValueError:
            pass
    options = [] if b"-----BEGIN CERTIFICATE-----" in data else ["-inform", "DER"]
    return run(["openssl", "x509", *options, "-pubkey", "-noout"], data)


def csr_public_key():
    return run(["openssl", "req", "-in", str(PRIVATE / "harmonysensorlab-release.csr"),
                "-pubkey", "-noout"])


def verify_profile(path):
    with tempfile.TemporaryDirectory(prefix="verify-profile-", dir=PRIVATE) as temp:
        output = Path(temp) / "result.json"
        run([str(JAVA), "-jar", str(SIGN_TOOL), "verify-profile", "-inFile", str(path),
             "-outFile", str(output)])
        result = json.loads(output.read_text())
    require(result.get("verifiedPassed") is True, "Profile signature verification failed.")
    content = result.get("content", {})
    bundle = content.get("bundle-info", {})
    require(content.get("type") == "release", "A Release Profile is required.")
    require(bundle.get("bundle-name") == BUNDLE, "Profile bundle does not match this app.")
    require(str(bundle.get("app-identifier", "")) == APP_ID, "Profile APP ID does not match this app.")
    validity = content.get("validity", {})
    require(float(validity.get("not-before", 0)) <= time.time() < float(validity.get("not-after", 0)),
            "Release Profile is not currently valid.")
    certificate = bundle.get("distribution-certificate", "")
    require(isinstance(certificate, str) and bool(certificate), "Profile has no distribution certificate.")
    require(certificate_public_key(certificate.encode()) == csr_public_key(),
            "Profile distribution certificate does not match the local signing key.")
    return content


def verify_material(certificate, profile):
    certificate, profile = Path(certificate).resolve(), Path(profile).resolve()
    for path in (certificate, profile):
        require(path.is_file() and PRIVATE.resolve() in path.parents,
                "Official certificate and Profile must exist in the private release directory.")
    chain = certificate.read_bytes()
    blocks = re.findall(rb"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", chain, re.S)
    require(bool(blocks), "Expected the official PEM certificate chain.")
    matches = [block for block in blocks if certificate_public_key(block) == csr_public_key()]
    require(len(matches) == 1, "Certificate chain must contain exactly one certificate matching the CSR.")
    run(["openssl", "x509", "-checkend", "0", "-noout"], matches[0])
    content = verify_profile(profile)
    return {"certificate": certificate, "profile": profile, "profileContent": content,
            "certificateSha256": hashlib.sha256(chain).hexdigest()}


def verify_hap(path, product):
    devices, minimum = PRODUCTS[product]
    with ZipFile(path) as package:
        manifest = json.loads(package.read("module.json"))
        app, module = manifest["app"], manifest["module"]
        require(app.get("bundleName") == BUNDLE and app.get("debug") is False,
                "Package must be this app in Release mode.")
        require(app.get("minAPIVersion") == minimum and app.get("targetAPIVersion") == 260000026,
                "Package SDK boundaries do not match the selected product.")
        require(set(module.get("deviceTypes", [])) == set(devices), "Package devices do not match the product.")
        require({p["name"] for p in module.get("requestPermissions", [])} == PERMISSIONS,
                "Package permissions do not match the privacy declaration.")
        require("ets/modules.abc" in package.namelist() and "resources.index" in package.namelist(),
                "Package executable code or resources are missing.")
        if "appIdentifier" in app:
            require(str(app["appIdentifier"]) == APP_ID, "Manifest APP ID is incorrect.")
    with tempfile.TemporaryDirectory(prefix="verify-hap-", dir=PRIVATE) as temp:
        temp = Path(temp)
        result = run([str(JAVA), "-jar", str(SIGN_TOOL), "verify-app", "-inFile", str(path),
                      "-outCertChain", str(temp / "chain.cer"), "-outProfile", str(temp / "profile.p7b")]).decode()
        for marker in ("verify-app success", "profile type is: release", "verify codesign success",
                       "verify permission sign success", "Huawei CBG Root CA"):
            require(marker in result, "Official Release package verification did not confirm all signing checks.")
        verify_profile(temp / "profile.p7b")
    return {"bytes": Path(path).stat().st_size, "sha256": hashlib.sha256(Path(path).read_bytes()).hexdigest(),
            "devices": devices, "minimumApi": minimum, "targetApi": 26, "profileType": "release",
            "bundleName": BUNDLE, "appId": APP_ID, "checks": "passed"}


def verify_app_container(path, hap, product):
    checked_hap = verify_hap(hap, product)
    with ZipFile(path) as archive:
        names = [name for name in archive.namelist() if name.endswith(".hap")]
        require(len(names) == 1 and "pack.info" in archive.namelist(), "Unexpected APP container contents.")
        embedded = archive.read(names[0])
    with ZipFile(io.BytesIO(embedded)) as inner, ZipFile(hap) as outer:
        exclusions = {"pack.info", ".pages.info"}
        left, right = set(inner.namelist()) - exclusions, set(outer.namelist()) - exclusions
        require(left == right and all(inner.read(name) == outer.read(name) for name in left),
                "APP executable payload does not match the verified Release HAP.")
    with tempfile.TemporaryDirectory(prefix="verify-app-container-", dir=PRIVATE) as temp:
        temp = Path(temp)
        # The official APP format signs the outer container; its embedded HAP need not have a signing block.
        result = run([str(JAVA), "-jar", str(SIGN_TOOL), "verify-app", "-inFile", str(path),
                      "-outCertChain", str(temp / "chain.cer"), "-outProfile", str(temp / "profile.p7b")]).decode()
        for marker in ("verify-app success", "Digest verify result: true", "Huawei CBG Root CA"):
            require(marker in result, "Official APP container signature verification failed.")
        verify_profile(temp / "profile.p7b")
    return {"bytes": Path(path).stat().st_size, "sha256": hashlib.sha256(Path(path).read_bytes()).hexdigest(),
            "profileType": "release", "devices": checked_hap["devices"], "minimumApi": checked_hap["minimumApi"],
            "targetApi": checked_hap["targetApi"], "bundleName": BUNDLE, "appId": APP_ID,
            "signatureScope": "APP container; executable payload matches a separately verified HAP",
            "checks": "official container signature, matching HAP payload and Release Profile passed"}


def _release_signature_identity(path):
    """Verify a container and identify its public certificate/Profile, never credentials."""
    with tempfile.TemporaryDirectory(prefix="verify-multidevice-signature-", dir=PRIVATE) as directory:
        temp = Path(directory)
        chain, profile = temp / "chain.cer", temp / "profile.p7b"
        result = run([str(JAVA), "-jar", str(SIGN_TOOL), "verify-app", "-inFile", str(path),
                      "-outCertChain", str(chain), "-outProfile", str(profile)]).decode()
        for marker in ("verify-app success", "Digest verify result: true", "Huawei CBG Root CA"):
            require(marker in result, "Official multi-device package signature verification failed.")
        content = verify_profile(profile)
        chain_bytes = chain.read_bytes()
        certificates = re.findall(rb"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----",
                                  chain_bytes, re.S)
        distribution_key = certificate_public_key(
            content["bundle-info"]["distribution-certificate"].encode())
        require(sum(certificate_public_key(item) == distribution_key for item in certificates) == 1,
                "Package certificate chain does not match the Release Profile distribution certificate.")
        return {"certificateChainSha256": hashlib.sha256(chain_bytes).hexdigest(),
                "profileSha256": hashlib.sha256(profile.read_bytes()).hexdigest(),
                "distributionPublicKeySha256": hashlib.sha256(distribution_key).hexdigest(),
                "profileType": content["type"], "bundleName": BUNDLE, "appId": APP_ID}


def _unique_zip_names(archive):
    names = archive.namelist()
    require(len(names) == len(set(names)), "Package contains duplicate ZIP entries.")
    return set(names)


def verify_multidevice_app_container(path, product_haps=None, *, expected_profile_sha256=None,
                                    expected_certificate_chain_sha256=None):
    """Verify one APP containing the preserved first-release device-specific HAPs.

    APP packing may replace pack.info and omit .pages.info. Every other HAP entry,
    including the complete manifest and executable code, must match its separately
    verified signed HAP. The official outer APP signature covers embedded HAPs.
    """
    products = FIRST_RELEASE_PRODUCTS
    if product_haps is None:
        product_haps = {product: ROOT / f"dist/packages/sensor-{product}-release-signed.hap"
                        for product in products}
    require(isinstance(product_haps, dict) and set(product_haps) == set(products),
            "Multi-device APP requires exactly default, pc and wearable HAP mappings.")
    path = Path(path)
    expected_names = {f"entry-{product}.hap": product for product in products}
    sources, checked, signatures = {}, {}, {}
    app_identity, source_summary = None, None
    devices = []
    for product in products:
        source = Path(product_haps[product])
        checked[product] = verify_hap(source, product)
        signatures[product] = _release_signature_identity(source)
        with ZipFile(source) as archive:
            names = _unique_zip_names(archive)
            require("pack.info" in names, "Reference HAP has no pack.info.")
            entries = {name: archive.read(name) for name in names}
        manifest = json.loads(entries["module.json"])
        app, module = manifest["app"], manifest["module"]
        require(app.get("buildMode") == "release" and app.get("bundleType") == "app" and
                app.get("apiReleaseType") == "Release", "Reference HAP must be a Release app.")
        require(module.get("name") == "entry" and module.get("type") == "entry" and
                module.get("packageName") == "entry", "Reference HAP logical module identity is incorrect.")
        identity = {key: value for key, value in app.items() if key not in
                    {"minAPIVersion", "minMinorAPIVersion", "minPatchAPIVersion"}}
        require(isinstance(app.get("versionCode"), int) and app["versionCode"] > 0 and
                isinstance(app.get("versionName"), str) and bool(app["versionName"]),
                "Reference HAP version identity is missing.")
        require(app_identity is None or app_identity == identity,
                "Reference HAPs disagree on app identity, version or target SDK.")
        app_identity = identity
        info = json.loads(entries["pack.info"])
        require(isinstance(info.get("summary"), dict) and
                len(info["summary"].get("modules", [])) == 1 and
                len(info.get("packages", [])) == 1, "Reference HAP pack.info structure is incorrect.")
        summary_app = {"bundleName": BUNDLE, "bundleType": "app",
                       "version": {"code": app["versionCode"], "name": app["versionName"]}}
        require(info["summary"].get("app") == summary_app,
                "Reference HAP pack.info app identity disagrees with its manifest.")
        summary_module, package = info["summary"]["modules"][0], info["packages"][0]
        product_devices, minimum = PRODUCTS[product]
        require(summary_module.get("deviceType") == product_devices and
                summary_module.get("apiVersion") ==
                {"compatible": minimum % 1000, "releaseType": "Release", "target": 26},
                "Reference HAP pack.info devices or SDK disagree with its manifest.")
        require(summary_module.get("distro") == {"moduleType": "entry", "installationFree": False,
                "deliveryWithInstall": True, "moduleName": "entry"} and
                summary_module.get("mainAbility") == module.get("mainElement"),
                "Reference HAP pack.info logical module disagrees with its manifest.")
        require(package == {"deviceType": product_devices, "moduleType": "entry",
                            "deliveryWithInstall": True, "name": f"entry-{product}"},
                "Reference HAP package-to-product mapping is incorrect.")
        require(source_summary is None or source_summary["app"] == info["summary"]["app"],
                "Reference HAP pack.info app identities disagree.")
        if source_summary is None:
            source_summary = info["summary"]
        sources[product] = {"entries": entries, "info": info, "manifest": manifest, "package": package}
        devices.extend(product_devices)
    signature = signatures[products[0]]
    require(all(value == signature for value in signatures.values()),
            "Reference HAPs use different Release Profiles or distribution certificates.")
    if expected_profile_sha256 is not None:
        require(signature["profileSha256"] == expected_profile_sha256,
                "Release Profile does not match the expected official Profile.")
    if expected_certificate_chain_sha256 is not None:
        require(signature["certificateChainSha256"] == expected_certificate_chain_sha256,
                "Distribution certificate chain does not match the expected official chain.")
    # Hvigor summarizes one logical entry across disjoint device variants, while
    # packages retains all three physical HAP names. Its compatible API is the
    # lowest variant boundary; encoded product boundaries remain in each HAP.
    expected_module = dict(source_summary["modules"][0])
    expected_module["deviceType"] = devices
    expected_info = {"summary": {"app": source_summary["app"], "modules": [expected_module]},
                     "packages": [sources[product]["package"] for product in products]}
    embedded_haps = []
    with ZipFile(path) as archive:
        names = _unique_zip_names(archive)
        require(names == set(expected_names) | {"pack.info", "pac.json"},
                "Multi-device APP must contain exactly the three expected HAPs and official metadata.")
        info = json.loads(archive.read("pack.info"))
        require(info == expected_info, "Multi-device APP pack.info does not match its HAP/device/API mapping.")
        require(json.loads(archive.read("pac.json")) == {"dataProcess": [], "specialAPIs": []},
                "Multi-device APP pac.json differs from the existing Release privacy metadata.")
        for name, product in expected_names.items():
            data = archive.read(name)
            reference = sources[product]
            with ZipFile(io.BytesIO(data)) as inner:
                inner_names = _unique_zip_names(inner)
                payload_names = set(reference["entries"]) - {"pack.info", ".pages.info"}
                require(inner_names - {"pack.info", ".pages.info"} == payload_names and
                        all(inner.read(item) == reference["entries"][item] for item in payload_names),
                        "Multi-device APP executable payload or manifest does not match its verified Release HAP.")
                require("pack.info" in inner_names and
                        json.loads(inner.read("pack.info")) in (reference["info"], expected_info),
                        "Embedded HAP pack.info is neither its original nor the aggregate official metadata.")
                if ".pages.info" in inner_names:
                    require(inner.read(".pages.info") == reference["entries"].get(".pages.info"),
                            "Embedded HAP page metadata differs from the verified Release HAP.")
            embedded_haps.append({"name": name, "product": product, "bytes": len(data),
                                  "sha256": hashlib.sha256(data).hexdigest(),
                                  "devices": checked[product]["devices"],
                                  "minimumApi": checked[product]["minimumApi"],
                                  "targetApi": checked[product]["targetApi"],
                                  "referenceHapSha256": checked[product]["sha256"],
                                  "payloadMatchesVerifiedHap": True})
    require(_release_signature_identity(path) == signature,
            "Multi-device APP does not use the same official Release Profile and certificate as its HAPs.")
    return {"bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "products": list(products), "devices": devices, "bundleName": BUNDLE, "appId": APP_ID,
            "versionCode": app_identity["versionCode"], "versionName": app_identity["versionName"],
            "targetApi": 26, "profileType": "release", "signatureIdentity": signature,
            "embeddedHaps": embedded_haps, "signatureScope": "official outer APP container",
            "checks": "official APP signature, identical Release Profile/certificate and all three preserved HAP payloads passed"}
