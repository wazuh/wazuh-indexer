#!/usr/bin/env python3
"""Compares the packages of two runs of 5_builderpackage_indexer (wazuh/wazuh-indexer#2130).

Downloads every package of the base run and of the candidate run from the internal
S3 bucket, pairs them by file name and compares, per package:

  - metadata: deb control fields and maintainer scripts; rpm name/version/release/
    arch, requires, provides, scripts and triggers;
  - tree: path, mode, owner and group of every entry;
  - content: sha256 of every file. A differing .jar/.zip whose entries (name, size,
    CRC, MANIFEST.MF aside) are identical is reported as "archive metadata only".

Every differing file is classified. Differences outside the expected classes make
the script exit with 1. Expected classes:
  version_json  usr/share/wazuh-indexer/VERSION.json (the commit field)
  snapshots     CTI snapshots, downloaded at assembly time
  engine        engine/**, built in each run (its commit is checked apart)
  changelog     changelog.Debian.gz, dated at build time
  archive_meta  .jar/.zip with identical entries (timestamps, MANIFEST.MF)

Usage: compare_packages.py BASE_RUN_ID CANDIDATE_RUN_ID WORKDIR
Env:   S3_RUNS_PREFIX  s3://<bucket>/wazuh-indexer/5_builderpackage_indexer
Needs: aws, dpkg-deb, docker (rpm packages are read in a UBI container), python3.
"""
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tarfile
import zipfile

UBI = "registry.access.redhat.com/ubi9/ubi:latest"
EXPECTED = ("version_json", "snapshots", "engine", "changelog", "archive_meta")


def sh(cmd, **kw):
    return subprocess.run(cmd, check=True, text=True, capture_output=True, **kw).stdout


def s3_packages(prefix, run_id):
    out = sh(["aws", "s3", "ls", f"{prefix}/{run_id}/"])
    names = []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) == 4 and parts[3].startswith("wazuh-indexer") and not parts[3].endswith(".sha512") \
                and parts[3].endswith((".deb", ".rpm", ".tar.gz")):
            names.append(parts[3])
    return sorted(names)


def extract(pkg, dest):
    """Extracts pkg into dest/root and returns (metadata text, tree lines)."""
    root = os.path.join(dest, "root")
    os.makedirs(root)
    if pkg.endswith(".deb"):
        sh(["dpkg-deb", "-x", pkg, root])
        ctl = os.path.join(dest, "control")
        sh(["dpkg-deb", "-e", pkg, ctl])
        fields = [l for l in sh(["dpkg-deb", "-f", pkg]).splitlines() if not l.startswith("Installed-Size")]
        scripts = []
        for name in sorted(os.listdir(ctl)):
            if name in ("md5sums", "control"):
                continue
            with open(os.path.join(ctl, name), errors="replace") as f:
                scripts.append(f"--- {name}\n{f.read()}")
        meta = "\n".join(fields) + "\n" + "\n".join(scripts)
        tree = []
        for line in sh(["dpkg-deb", "-c", pkg]).splitlines():
            p = line.split()
            tree.append(f"{p[0]} {p[1]} {p[5]}")
        return meta, sorted(tree)
    if pkg.endswith(".rpm"):
        d = os.path.dirname(os.path.abspath(pkg))
        b = os.path.basename(pkg)
        script = (
            "set -e; dnf install -y -q cpio >/dev/null 2>&1; cd /w; "
            f"rpm -qp --qf '%{{NAME}} %{{VERSION}} %{{RELEASE}} %{{ARCH}}\\n' {b} > meta.txt; "
            f"for o in --requires --provides --scripts --triggers; do echo \"--- $o\" >> meta.txt; rpm -qp $o {b} >> meta.txt; done; "
            f"rpm -qp --dump {b} > dump.txt; "
            f"mkdir -p root_{b} && cd root_{b} && rpm2cpio ../{b} | cpio -idm --quiet; "
            "chmod -R a+rX /w"
        )
        sh(["docker", "run", "--rm", "-v", f"{d}:/w", UBI, "bash", "-c", script])
        shutil.rmtree(root)
        os.rename(os.path.join(d, f"root_{b}"), root)
        with open(os.path.join(d, "meta.txt")) as f:
            meta = f.read()
        tree = []
        with open(os.path.join(d, "dump.txt")) as f:
            for line in f:
                p = line.split()
                # path size mtime digest mode owner group isconfig isdoc rdev symlink
                tree.append(f"{p[4]} {p[5]}/{p[6]} {p[0]}")
        for n in ("meta.txt", "dump.txt"):
            os.remove(os.path.join(d, n))
        return meta, sorted(tree)
    with tarfile.open(pkg) as t:
        tree = sorted(f"{oct(m.mode)} {m.uname}/{m.gname} {m.name}" for m in t.getmembers())
        t.extractall(root)
    return "", tree


def file_hashes(root):
    out = {}
    for d, _, files in os.walk(root):
        for f in files:
            p = os.path.join(d, f)
            if os.path.islink(p):
                continue
            h = hashlib.sha256()
            with open(p, "rb") as fh:
                for chunk in iter(lambda: fh.read(1 << 20), b""):
                    h.update(chunk)
            out[os.path.relpath(p, root)] = h.hexdigest()
    return out


def zip_entries(path):
    try:
        with zipfile.ZipFile(path) as z:
            return sorted((i.filename, i.file_size, i.CRC) for i in z.infolist()
                          if not i.filename.endswith("MANIFEST.MF"))
    except zipfile.BadZipFile:
        return None


def classify(rel, a_root, b_root):
    if rel.endswith("VERSION.json"):
        return "version_json"
    if "/snapshots/" in rel:
        return "snapshots"
    if "/engine/" in rel or rel.startswith("engine/"):
        return "engine"
    if rel.endswith("changelog.Debian.gz"):
        return "changelog"
    if rel.endswith((".jar", ".zip")):
        ea, eb = zip_entries(os.path.join(a_root, rel)), zip_entries(os.path.join(b_root, rel))
        if ea is not None and ea == eb:
            return "archive_meta"
    return "UNEXPECTED"


def main():
    base, cand, work = sys.argv[1:4]
    prefix = os.environ["S3_RUNS_PREFIX"].rstrip("/")
    shutil.rmtree(work, ignore_errors=True)
    os.makedirs(work)
    a_names, b_names = s3_packages(prefix, base), s3_packages(prefix, cand)
    print(f"base {base}: {a_names}\ncandidate {cand}: {b_names}")
    failures = 0
    only = sorted(set(a_names) ^ set(b_names))
    if only:
        failures += 1
        print(f"\nUNEXPECTED: package names differ: {only}")
    for name in sorted(set(a_names) & set(b_names)):
        print(f"\n===== {name}")
        sides = {}
        for side, run in (("base", base), ("cand", cand)):
            d = os.path.join(work, side)
            os.makedirs(d)
            pkg = os.path.join(d, name)
            sh(["aws", "s3", "cp", "--only-show-errors", f"{prefix}/{run}/{name}", pkg])
            meta, tree = extract(pkg, d)
            os.remove(pkg)
            sides[side] = (d, meta, tree)
        (ad, am, at), (bd, bm, bt) = sides["base"], sides["cand"]
        if am != bm:
            failures += 1
            print("UNEXPECTED: metadata differs")
            for l in sorted(set(am.splitlines()) ^ set(bm.splitlines()))[:40]:
                print(f"   {l}")
        else:
            print("metadata: identical")
        if at != bt:
            failures += 1
            print("UNEXPECTED: tree (path, mode, owner) differs")
            for l in sorted(set(at) ^ set(bt))[:40]:
                print(f"   {l}")
        else:
            print(f"tree: identical ({len(at)} entries)")
        ar, br = os.path.join(ad, "root"), os.path.join(bd, "root")
        ha, hb = file_hashes(ar), file_hashes(br)
        classes = {}
        for rel in sorted(set(ha) | set(hb)):
            if ha.get(rel) != hb.get(rel):
                c = classify(rel, ar, br) if rel in ha and rel in hb else "UNEXPECTED"
                classes.setdefault(c, []).append(rel)
        print(f"files: {len(ha)} compared, {sum(len(v) for v in classes.values())} differ")
        for c in EXPECTED + ("UNEXPECTED",):
            if c in classes:
                print(f"   {c}: {len(classes[c])}")
                for rel in classes[c][:15]:
                    print(f"      {rel}")
        if "version_json" in classes:
            for side, root in (("base", ar), ("cand", br)):
                rel = classes["version_json"][0]
                with open(os.path.join(root, rel)) as f:
                    print(f"   VERSION.json {side}: {json.load(f).get('commit')}")
        if "UNEXPECTED" in classes:
            failures += 1
        shutil.rmtree(ad)
        shutil.rmtree(bd)
    print(f"\n{'FAILED' if failures else 'OK'}: {failures} unexpected difference group(s)")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
