import importlib.util
import io
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
import zipfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
spec = importlib.util.spec_from_file_location("lint_workflows", ROOT / "scripts/lint-workflows.py")
lint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint)

BINARY = b"reviewed actionlint bytes"


def tarball(members):
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w:gz") as bundle:
        for name, data in members:
            info = tarfile.TarInfo(name)
            if data is None:
                info.type = tarfile.SYMTYPE
                info.linkname = "/etc/passwd"
                bundle.addfile(info)
            else:
                info.size = len(data)
                bundle.addfile(info, io.BytesIO(data))
    return buffer.getvalue()


class LintWorkflowsTests(unittest.TestCase):
    def write(self, directory, name, data):
        path = Path(directory) / name
        path.write_bytes(data)
        return path

    def test_only_the_binary_is_taken_from_the_archive(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = self.write(directory, "a.tar.gz", tarball([("README.md", b"docs"), ("../escape", b"x"),
                                                                ("actionlint", BINARY)]))
            self.assertEqual(lint.extract_binary(archive, "darwin_arm64.tar.gz"), ("actionlint", BINARY))
            self.assertEqual(sorted(p.name for p in Path(directory).iterdir()), ["a.tar.gz"])

    def test_a_link_in_place_of_the_binary_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = self.write(directory, "a.tar.gz", tarball([("actionlint", None)]))
            with self.assertRaises(ValueError):
                lint.extract_binary(archive, "linux_amd64.tar.gz")

    def test_windows_zip(self):
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w") as bundle:
            bundle.writestr("actionlint.exe", BINARY)
        with tempfile.TemporaryDirectory() as directory:
            archive = self.write(directory, "a.zip", buffer.getvalue())
            self.assertEqual(lint.extract_binary(archive, "windows_amd64.zip"), ("actionlint.exe", BINARY))

    def test_every_pinned_asset_has_a_digest_and_unknown_platforms_fail(self):
        self.assertTrue(all(len(digest) == 64 for digest in lint.HASHES.values()))
        with patch.object(lint.platform, "system", return_value="Plan9"):
            with self.assertRaises(ValueError):
                lint.asset_name()
        with patch.object(lint.platform, "system", return_value="Linux"), \
                patch.object(lint.platform, "machine", return_value="aarch64"):
            self.assertEqual(lint.asset_name(), "linux_arm64.tar.gz")

    def test_install_writes_an_executable_from_the_verified_download(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = self.write(directory, "a.tar.gz", tarball([("actionlint", BINARY)]))
            with patch.object(lint, "asset_name", return_value="linux_amd64.tar.gz"), \
                    patch.object(lint, "verified_download", return_value=archive) as download:
                binary = lint.install(Path(directory) / "tools", Path(directory) / "cache")
            url, digest = download.call_args.args[:2]
            self.assertTrue(url.startswith("https://github.com/rhysd/actionlint/releases/download/v"))
            self.assertEqual(digest, lint.HASHES["linux_amd64.tar.gz"])
            self.assertEqual(binary.read_bytes(), BINARY)


if __name__ == "__main__":
    unittest.main()
