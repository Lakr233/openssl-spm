#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Exercise notice staging and the real merger with synthetic Apple tools."""

import hashlib
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLATFORMS = [
    "macosx",
    "maccatalyst",
    "iphoneos",
    "iphonesimulator",
    "appletvos",
    "appletvsimulator",
    "watchos",
    "watchsimulator",
    "xros",
    "xrsimulator",
]


def run(*command, cwd=None, env=None, check=True):
    result = subprocess.run(
        command, cwd=cwd, env=env, capture_output=True, text=True, check=False
    )
    if check and result.returncode:
        raise RuntimeError(f"{command}:\n{result.stdout}{result.stderr}")
    return result


def git(root, *args):
    return run("git", "-C", str(root), *args).stdout.strip()


def initialize(root, origin):
    git(root, "init", "-q")
    git(root, "remote", "add", "origin", origin)
    git(root, "add", ".")
    git(
        root,
        "-c",
        "user.name=Notice fixture",
        "-c",
        "user.email=fixture@example.invalid",
        "-c",
        "commit.gpgsign=false",
        "commit",
        "-qm",
        "fixture source",
    )


def fake_tool(name, args):
    if name == "xcodebuild":
        output = Path(args[args.index("-output") + 1])
        output.mkdir(parents=True)
        for index, argument in enumerate(args):
            if argument != "-framework":
                continue
            source = Path(args[index + 1])
            variant = source.parent.name
            identifier = {
                "macosx": "macos-arm64",
                "maccatalyst": "ios-arm64-maccatalyst",
            }.get(variant, variant + "-arm64")
            shutil.copytree(source, output / identifier / source.name, symlinks=True)
        Path(os.environ["XCODEBUILD_MARKER"]).write_text(
            "synthetic framework merge only"
        )
    elif args[:2] == ["-x", "-k"]:
        with zipfile.ZipFile(args[2]) as archive:
            for info in archive.infolist():
                relative = Path(info.filename)
                if relative.is_absolute() or ".." in relative.parts:
                    raise ValueError("unsafe fixture archive path")
                target = Path(args[3]) / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                if stat.S_ISLNK(info.external_attr >> 16):
                    target.symlink_to(archive.read(info).decode())
                elif info.is_dir():
                    target.mkdir(exist_ok=True)
                else:
                    target.write_bytes(archive.read(info))
    else:
        source, output = map(Path, args[-2:])
        mutation = os.environ.get("NOTICE_ARCHIVE_MUTATION")
        with zipfile.ZipFile(output, "w") as archive:
            if mutation == "root-symlink":
                link = zipfile.ZipInfo(source.name)
                link.external_attr = (stat.S_IFLNK | 0o777) << 16
                archive.writestr(link, str(source.resolve()))
                return
            if mutation == "parent-symlink":
                alias = zipfile.ZipInfo(source.name + "/notice-alias/")
                alias.external_attr = (stat.S_IFDIR | 0o700) << 16
                archive.writestr(alias, b"")
            for path in sorted(source.rglob("*")):
                name = str(path.relative_to(source.parent))
                info = zipfile.ZipInfo(
                    name + ("/" if path.is_dir() and not path.is_symlink() else "")
                )
                info.external_attr = path.lstat().st_mode << 16
                if mutation == "parent-symlink" and name.endswith(
                    "/Licenses/openssl-spm"
                ):
                    info.filename = name
                    info.external_attr = (stat.S_IFLNK | 0o777) << 16
                    archive.writestr(info, "../notice-alias")
                    continue
                if mutation == "file-symlink" and name.endswith(
                    "/Licenses/openssl-spm/LICENSE"
                ):
                    info.external_attr = (stat.S_IFLNK | 0o777) << 16
                if path.is_symlink():
                    archive.writestr(info, os.readlink(path))
                elif path.is_file():
                    archive.writestr(info, path.read_bytes())
                else:
                    archive.writestr(info, b"")


class Packaging(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="openssl-notices-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.wrapper = self.root / "wrapper"
        self.wrapper.mkdir()
        shutil.copytree(ROOT / "Script", self.wrapper / "Script")
        shutil.copy2(ROOT / "LICENSE", self.wrapper / "LICENSE")
        (self.wrapper / ".root").touch()
        initialize(self.wrapper, "https://github.com/Lakr233/openssl-spm.git")
        self.source = self.root / "openssl"
        shutil.copytree(ROOT / "Tests/Fixtures/openssl-3.6.2", self.source)
        (self.source / "NOTICE.fixture").write_text(
            "A tracked optional notice from the compiled source.\n"
        )
        initialize(self.source, "https://github.com/openssl/openssl.git")
        self.tool = self.wrapper / "Script/package-notices.sh"
        self.notices = self.root / "Licenses"
        run("bash", str(self.tool), "stage", str(self.source), str(self.notices))

    def test_actual_pinned_notices_and_checked_out_revision_are_preserved(self):
        expected = {
            "LICENSE.txt": "49cc83d2ee29d13453188217f0e4edd70c7f842f",
            "AUTHORS.md": "5b036a0d8358167c87c7fa275cc671cd222dcce6",
            "VERSION.dat": "2407410ed5fecbe09d603c34892c533f6db03a12",
        }
        for name, blob in expected.items():
            raw = (self.source / name).read_bytes()
            self.assertEqual(
                hashlib.sha1(
                    b"blob " + str(len(raw)).encode() + b"\0" + raw
                ).hexdigest(),
                blob,
            )
            self.assertEqual((self.notices / "OpenSSL" / name).read_bytes(), raw)
        manifest = json.loads((self.notices / "manifest.json").read_bytes())
        self.assertEqual(manifest["schema_version"], 1)
        components = {row["name"]: row for row in manifest["components"]}
        for name, source in (("OpenSSL", self.source), ("openssl-spm", self.wrapper)):
            self.assertEqual(
                components[name]["revision"], git(source, "rev-parse", "HEAD")
            )
            self.assertEqual(
                components[name]["tree"], git(source, "rev-parse", "HEAD^{tree}")
            )
            self.assertNotIn("source_patch", components[name])
        self.assertEqual(
            (self.notices / "openssl-spm/LICENSE").read_bytes(),
            (ROOT / "LICENSE").read_bytes(),
        )
        self.assertTrue((self.notices / "OpenSSL/NOTICE.fixture").is_file())

    def test_tracked_source_changes_have_a_patch_sidecar(self):
        (self.source / "VERSION.dat").write_text("modified source fixture\n")
        staged = self.root / "patched"
        run("bash", str(self.tool), "stage", str(self.source), str(staged))
        component = json.loads((staged / "manifest.json").read_bytes())["components"][0]
        raw = (staged / component["source_patch"]["path"]).read_bytes()
        self.assertEqual(
            raw,
            run(
                "git",
                "-C",
                str(self.source),
                "diff",
                "--no-ext-diff",
                "--binary",
                "HEAD",
                "--",
            ).stdout.encode(),
        )
        self.assertEqual(
            component["source_patch"]["sha256"], hashlib.sha256(raw).hexdigest()
        )
        self.assertEqual(
            (staged / "OpenSSL/VERSION.dat").read_text(), "modified source fixture\n"
        )

    def test_missing_changed_unlisted_and_symlink_notices_are_refused(self):
        for case in ("missing", "changed", "unlisted", "symlink", "invalid-with-patch"):
            with self.subTest(case=case):
                target = self.root / case
                shutil.copytree(self.notices, target)
                license_path = target / "OpenSSL/LICENSE.txt"
                if case == "missing":
                    license_path.unlink()
                elif case == "changed":
                    license_path.write_bytes(b"wrong license")
                elif case == "unlisted":
                    (target / "unlisted").touch()
                elif case == "symlink":
                    license_path.unlink()
                    license_path.symlink_to(self.source / "LICENSE.txt")
                else:
                    value = json.loads((target / "manifest.json").read_bytes())
                    value["components"][0]["revision"] = "invalid"
                    raw = b"patch"
                    (target / "OpenSSL/source.patch").write_bytes(raw)
                    value["components"][0]["source_patch"] = {
                        "path": "OpenSSL/source.patch",
                        "sha256": hashlib.sha256(raw).hexdigest(),
                    }
                    (target / "manifest.json").write_text(json.dumps(value))
                result = run("bash", str(self.tool), "verify", str(target), check=False)
                self.assertNotEqual(result.returncode, 0)

    def artifacts(self):
        artifacts = self.root / "artifacts"
        for platform in PLATFORMS:
            base = artifacts / platform
            (base / "lib").mkdir(parents=True)
            (base / "lib/libssl.a").write_bytes(
                b"synthetic static library, not an Apple build"
            )
            (base / "include/openssl").mkdir(parents=True)
            (base / "include/openssl/ssl.h").write_text("#include <openssl/base.h>\n")
            (base / "include/openssl/base.h").write_text("/* synthetic header */\n")
            (base / "include/module.modulemap").write_text(
                'module libssl { header "openssl/ssl.h" export * }\n'
            )
            shutil.copytree(self.notices, base / "Licenses")
        return artifacts

    def merge(self, artifacts, *, mutation=""):
        tools = self.root / "tools"
        tools.mkdir()
        for name in ("xcodebuild", "ditto"):
            executable = tools / name
            executable.write_text(
                '#!/bin/bash\nexec uv run --offline --no-project "'
                + str(ROOT / "Script/test-notices.py")
                + '" --fake-tool '
                + name
                + ' "$@"\n'
            )
            executable.chmod(0o700)
        otool = tools / "otool"
        otool.write_text('#!/bin/bash\nprintf "cmd LC_BUILD_VERSION\\nminos 11.0\\n"\n')
        otool.chmod(0o700)
        sed = tools / "sed"
        sed.write_text(
            '#!/bin/bash\nif [ "$(uname)" = Linux ] && [ "$1" = -i ] && [ "$2" = "" ]; then\n'
            'shift 2\nexec /usr/bin/sed -i "$@"\nfi\nexec /usr/bin/sed "$@"\n'
        )
        sed.chmod(0o700)
        output = self.root / "libssl.xcframework.zip"
        self.marker = self.root / "xcodebuild-invoked"
        env = os.environ | {
            "PATH": str(tools) + os.pathsep + os.environ["PATH"],
            "XCODEBUILD_MARKER": str(self.marker),
            "NOTICE_ARCHIVE_MUTATION": mutation,
        }
        result = run(
            "bash",
            str(self.wrapper / "Script/merge-xcframework.sh"),
            str(artifacts),
            str(output),
            cwd=self.wrapper,
            env=env,
            check=False,
        )
        return result, output

    def test_complete_zip_carries_both_component_notices_and_provenance(self):
        result, output = self.merge(self.artifacts())
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        with zipfile.ZipFile(output) as archive:
            prefix = "OpenSSL.Package.xcframework/Licenses/"
            self.assertEqual(
                archive.read(prefix + "manifest.json"),
                (self.notices / "manifest.json").read_bytes(),
            )
            self.assertEqual(
                archive.read(prefix + "OpenSSL/LICENSE.txt"),
                (self.source / "LICENSE.txt").read_bytes(),
            )
            self.assertEqual(
                archive.read(prefix + "openssl-spm/LICENSE"),
                (ROOT / "LICENSE").read_bytes(),
            )
            self.assertTrue(
                any(
                    stat.S_ISLNK(info.external_attr >> 16)
                    for info in archive.infolist()
                )
            )

    def test_merge_refuses_missing_or_different_slice_context_before_apple_tools(self):
        for case in ("missing", "different"):
            with self.subTest(case=case):
                artifacts = self.artifacts()
                path = artifacts / "xrsimulator/Licenses/manifest.json"
                if case == "missing":
                    path.unlink()
                else:
                    manifest = json.loads(path.read_bytes())
                    manifest["components"][0]["revision"] = "a" * 40
                    path.write_text(json.dumps(manifest))
                result, output = self.merge(artifacts)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.marker.exists())
                self.assertFalse(output.exists())
                shutil.rmtree(artifacts)
                shutil.rmtree(self.root / "tools")

    def test_original_zip_notice_symlinks_and_parent_symlinks_are_refused(self):
        for mutation in ("file-symlink", "parent-symlink"):
            with self.subTest(mutation=mutation):
                artifacts = self.artifacts()
                result, output = self.merge(artifacts, mutation=mutation)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("nonregular notice payload", result.stderr)
                self.assertFalse(output.exists())
                with zipfile.ZipFile(
                    self.wrapper / "BinaryTarget/OpenSSL.Package.xcframework.zip"
                ) as archive:
                    member = "OpenSSL.Package.xcframework/Licenses/openssl-spm"
                    if mutation == "file-symlink":
                        member += "/LICENSE"
                        self.assertEqual(
                            archive.read(member), (ROOT / "LICENSE").read_bytes()
                        )
                    self.assertTrue(
                        stat.S_ISLNK(archive.getinfo(member).external_attr >> 16)
                    )
                shutil.rmtree(artifacts)
                shutil.rmtree(self.root / "tools")

    def test_top_xcframework_zip_symlink_cannot_supply_notices_from_outside_extraction(
        self,
    ):
        result, output = self.merge(self.artifacts(), mutation="root-symlink")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unsafe extracted XCFramework directory", result.stderr)
        self.assertFalse(output.exists())
        with zipfile.ZipFile(
            self.wrapper / "BinaryTarget/OpenSSL.Package.xcframework.zip"
        ) as archive:
            self.assertEqual(archive.namelist(), ["OpenSSL.Package.xcframework"])
            entry = archive.infolist()[0]
            self.assertTrue(stat.S_ISLNK(entry.external_attr >> 16))
            target = Path(archive.read(entry).decode())
            self.assertEqual(
                target, self.wrapper / "BinaryTarget/OpenSSL.Package.xcframework"
            )
            self.assertTrue((target / "Licenses/manifest.json").is_file())


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--fake-tool":
        fake_tool(sys.argv[2], sys.argv[3:])
    else:
        unittest.main()
