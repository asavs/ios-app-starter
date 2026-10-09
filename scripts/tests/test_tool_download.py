import hashlib
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tool_download import verified_download

DATA = b"reviewed public tool bytes"
DIGEST = hashlib.sha256(DATA).hexdigest()
URL = "https://example.invalid/tool"


def response(data):
    def download(command, **kwargs):
        Path(command[command.index("--output") + 1]).write_bytes(data)
        return subprocess.CompletedProcess(command, 0)
    return download


class ToolDownloadTests(unittest.TestCase):
    def test_cold_then_warm_works_without_network(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(subprocess, "run", side_effect=response(DATA)) as transport:
                path = verified_download(URL, DIGEST, "tool", directory)
                self.assertEqual(transport.call_count, 1)
            with patch.object(subprocess, "run", side_effect=AssertionError("warm cache must not download")):
                self.assertEqual(verified_download(URL, DIGEST, "tool", directory), path)
            self.assertEqual(path.read_bytes(), DATA)

    def test_tampered_cache_is_repaired_before_use(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / DIGEST / "tool"
            target.parent.mkdir()
            target.write_bytes(b"tampered")
            with patch.object(subprocess, "run", side_effect=response(DATA)) as transport:
                self.assertEqual(verified_download(URL, DIGEST, "tool", directory).read_bytes(), DATA)
                self.assertEqual(transport.call_count, 1)

    def test_bad_download_is_not_published(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(subprocess, "run", side_effect=response(b"untrusted")):
                with self.assertRaises(ValueError):
                    verified_download(URL, DIGEST, "tool", directory)
            self.assertFalse((Path(directory) / DIGEST / "tool").exists())
            self.assertFalse(list(Path(directory).rglob("download-*")))

    def test_failed_transport_preserves_verified_other_version(self):
        with tempfile.TemporaryDirectory() as directory:
            existing = Path(directory) / "previous"
            existing.write_bytes(DATA)
            with patch.object(subprocess, "run", side_effect=subprocess.CalledProcessError(22, "curl")):
                with self.assertRaises(subprocess.CalledProcessError):
                    verified_download(URL, DIGEST, "tool", directory)
            self.assertEqual(existing.read_bytes(), DATA)
            self.assertFalse((Path(directory) / DIGEST / "tool").exists())


if __name__ == "__main__":
    unittest.main()
