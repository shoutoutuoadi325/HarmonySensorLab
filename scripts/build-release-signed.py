#!/usr/bin/env python3
"""Build and verify selected official Release products, then save local package artifacts."""
import argparse
import json
import os
import shutil
import signal
import subprocess
import tempfile
import time
from pathlib import Path
from release_signing import ROOT, PRIVATE, PRODUCTS, FIRST_RELEASE_PRODUCTS, STUDIO, verify_material, verify_hap, verify_app_container, require


def encrypted_hvigor_passwords(password, store):
    # Hvigor expects IDE-encrypted password fields and a material directory next to the keystore.
    destination = store.parent / "material"
    if not destination.exists():
        debug = json.loads((ROOT / ".signing/deveco-signing.json").read_text())
        native = Path(debug[0]["material"]["storeFile"]).resolve().parent / "material"
        require(native.is_dir(), "Native IDE password protection material is unavailable.")
        require(all((native / name).is_dir() for name in ("fd", "ac", "ce")),
                "Native IDE password protection material is incomplete.")
        with tempfile.TemporaryDirectory(prefix="password-material-", dir=PRIVATE) as temp:
            staged = Path(temp) / "material"
            shutil.copytree(native, staged)
            for item in [staged, *staged.rglob("*")]:
                require(not item.is_symlink(), "Password protection material must not contain symlinks.")
                item.chmod(0o700 if item.is_dir() else 0o600)
            staged.rename(destination)
    with tempfile.TemporaryDirectory(prefix="hvigor-password-", dir=PRIVATE) as temp:
        output = Path(temp) / "encrypted.json"
        modules = Path(temp) / "node_modules" / "@ohos"
        modules.mkdir(parents=True)
        (modules / "hvigor").symlink_to(STUDIO / "tools/hvigor/hvigor", target_is_directory=True)
        environment = os.environ.copy()
        environment["NODE_PATH"] = str(Path(temp) / "node_modules")
        request = {"password": password, "materialDirectory": str(store.parent),
                   "outputFile": str(output), "studioDirectory": str(STUDIO)}
        result = subprocess.run([str(STUDIO / "tools/node/bin/node"), str(ROOT / "scripts/encrypt-hvigor-password.cjs")],
                                input=json.dumps(request), capture_output=True, text=True, timeout=30, env=environment)
        require(result.returncode == 0 and output.is_file(), "IDE password format verification failed.")
        return json.loads(output.read_text())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--certificate", type=Path, default=PRIVATE / "harmonysensorlab-release.cer")
    parser.add_argument("--profile", type=Path, default=PRIVATE / "harmonysensorlab-release.p7b")
    parser.add_argument("--check-material-only", action="store_true")
    parser.add_argument("--report-file", type=Path,
                        default=ROOT / "reports/store-submission/release-package-verification.json")
    parser.add_argument("--products", nargs="+", choices=PRODUCTS, default=list(FIRST_RELEASE_PRODUCTS),
                        help="Products to build; defaults to the approved first release without TV.")
    args = parser.parse_args()
    if len(args.products) != len(set(args.products)):
        parser.error("Each product must be selected only once.")
    verified = verify_material(args.certificate, args.profile)
    if args.check_material_only:
        print("Official Release certificate/Profile verified for the expected app and local CSR.")
        return
    subprocess.run(["python3", str(ROOT / "scripts/preflight-release-privacy.py")], check=True, cwd=ROOT)
    material = json.loads((PRIVATE / "material.json").read_text())
    store = Path(material["keyStore"]).resolve()
    require(store.is_file() and PRIVATE.resolve() in store.parents, "Local Release keystore is unavailable.")
    require(bool(material.get("storePassword")), "Private keystore password is unavailable.")
    config = {"name": "local_release", "type": "HarmonyOS", "material": {
        "certpath": str(verified["certificate"]), "profile": str(verified["profile"]),
        "keyAlias": material["keyAlias"], "storeFile": str(store), "signAlg": "SHA256withECDSA"}}
    profile_file = ROOT / "build-profile.json5"
    lock = ROOT / ".signing/build.lock"
    descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    backup = ROOT / ".signing/build-profile-release-backup.json5"
    mutated = False
    backup_created = False
    try:
        config["material"].update(encrypted_hvigor_passwords(material["storePassword"], store))
        original, original_mode = profile_file.read_text(), profile_file.stat().st_mode & 0o777
        profile = json.loads(original)
        profile["app"]["signingConfigs"] = [config]
        for product in profile["app"]["products"]:
            product["signingConfig"] = config["name"]
        require(not backup.exists(), "A prior signing backup exists; resolve it before another build.")
        backup_descriptor = os.open(backup, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        backup_created = True
        with os.fdopen(backup_descriptor, "w") as file:
            file.write(original)
        profile_file.chmod(0o600)
        mutated = True
        profile_file.write_text(json.dumps(profile, ensure_ascii=False, indent=2) + "\n")
        report = ROOT / "reports/store-submission"
        report.mkdir(parents=True, exist_ok=True)
        destination = ROOT / "dist/packages"
        destination.mkdir(parents=True, exist_ok=True)
        results = []
        with tempfile.TemporaryDirectory(prefix="release-build-", dir=PRIVATE) as temp:
            stage = Path(temp)
            for product in args.products:
                for kind in ("hap", "app"):
                    started = time.time()
                    build = subprocess.run([str(ROOT / "scripts/build.sh"), product, "release", kind],
                                           cwd=ROOT, capture_output=True, text=True)
                    output = build.stdout + build.stderr
                    output = output.replace(material["storePassword"], "[private signing value]")
                    for key, value in config["material"].items():
                        if isinstance(value, str) and value and ("password" in key.lower() or len(value) > 8):
                            output = output.replace(value, "[private signing value]")
                    (report / f"build-release-{product}-{kind}-signed.log").write_text(output)
                    require(build.returncode == 0, f"Release {kind} build failed for {product}; see sanitized log.")
                    target = stage / f"sensor-{product}-release-signed.{kind}"
                    hap = stage / f"sensor-{product}-release-signed.hap"
                    if kind == "hap":
                        source = ROOT / f"entry/build/{product}/outputs/{product}/entry-{product}-signed.hap"
                        require(source.is_file(), "Expected signed HAP build output is missing.")
                        shutil.copy2(source, target)
                        checked = verify_hap(target, product)
                    else:
                        candidates = [p for p in (ROOT / f"build/outputs/{product}").glob("*-signed.app")
                                      if p.stat().st_mtime >= started - 1]
                        valid = []
                        for candidate in candidates:
                            try:
                                checked = verify_app_container(candidate, hap, product)
                                valid.append((candidate, checked))
                            except (ValueError, OSError, KeyError):
                                continue
                        require(len(valid) == 1, "Expected exactly one fresh, verified signed APP output.")
                        source, checked = valid[0]
                        shutil.copy2(source, target)
                    results.append({"file": str((destination / target.name).relative_to(ROOT)), **checked})
                    print(f"Verified official Release {kind.upper()}: {product}")
            for item in stage.iterdir():
                shutil.copy2(item, destination / item.name)
        args.report_file.write_text(
            json.dumps({"products": args.products, "packages": results, "certificateSha256": verified["certificateSha256"],
                        "note": "Official Release signing verified; this does not establish store approval."},
                       ensure_ascii=False, indent=2) + "\n")
    finally:
        if mutated:
            profile_file.write_text(original)
            profile_file.chmod(original_mode)
        if backup_created:
            backup.unlink(missing_ok=True)
        os.close(descriptor)
        lock.unlink(missing_ok=True)


def interrupted(signum, frame):
    raise SystemExit("Release build interrupted; restoring portable signing configuration.")


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGHUP, interrupted)
    try:
        main()
    except (ValueError, OSError, KeyError, subprocess.SubprocessError) as error:
        raise SystemExit(str(error))
