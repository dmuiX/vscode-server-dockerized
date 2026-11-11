"""Startup regression tests with synthetic credentials and stubbed account commands."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
ENTRYPOINT = Path(os.environ.get("ENTRYPOINT_UNDER_TEST", ROOT / "entrypoint.sh"))
PASSWORD = "synthetic-sudo-password-not-a-secret"


class StartupSecurityTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.temp = Path(self.directory.name)
        self.bin = self.temp / "bin"
        self.bin.mkdir()
        self.password = self.temp / "password"
        self.password.write_text(PASSWORD + "\n")
        self.calls = self.temp / "calls"
        self.captured_password = self.temp / "chpasswd-input"
        self.env = {
            **os.environ,
            "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
            "USERNAME": "vscode",
            "PUID": "1000",
            "PGID": "1000",
            "DEBUG": "true",
            "USER_PASSWORD_FILE": str(self.password),
            "MOCK_CALLS": str(self.calls),
            "MOCK_PASSWORD": str(self.captured_password),
        }
        # Never execute real account, ownership or application commands on the host.
        for name in ("groupmod", "groupadd", "usermod", "useradd", "install"):
            self.stub(name, f'printf "%s\\n" "{name} $*" >> "$MOCK_CALLS"')
        self.stub("getent", "exit 2")
        self.stub("id", 'if [[ "$1" == -u ]]; then echo "${MOCK_UID:-$PUID}"; else echo "$PGID"; fi')
        self.stub("chpasswd", '/bin/cat > "$MOCK_PASSWORD"')
        self.stub("gosu", '''
printf '%s\n' "gosu $*" >> "$MOCK_CALLS"
printf 'Web UI available at http://localhost:8000/\n'
''')

    def stub(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/bash\nset -eu\n" + body + "\n")
        path.chmod(0o700)

    def run_startup(self, **overrides):
        return subprocess.run(
            ["bash", "-x", str(ENTRYPOINT)],
            env={**self.env, **overrides},
            capture_output=True,
            text=True,
            check=False,
        )

    def test_valid_startup_keeps_sudo_without_logging_credentials(self):
        result = self.run_startup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn(PASSWORD, result.stdout + result.stderr)
        self.assertNotIn(PASSWORD, self.calls.read_text())
        self.assertEqual(self.captured_password.read_text(), "vscode:" + PASSWORD + "\n")
        calls = self.calls.read_text()
        self.assertIn("usermod -aG sudo vscode", calls)
        self.assertIn("--without-connection-token", calls)
        self.assertNotIn("--connection-token-file", calls)

    def test_debug_traces_nonsecret_initialization_only(self):
        enabled = self.run_startup(DEBUG="true")
        self.assertEqual(enabled.returncode, 0, enabled.stderr)
        self.assertIn("+ usermod -aG sudo vscode", enabled.stderr)
        self.assertIn("+ install -d", enabled.stderr)
        self.assertNotIn("+ chpasswd", enabled.stderr)
        self.assertNotIn(PASSWORD, enabled.stdout + enabled.stderr)
        disabled = self.run_startup(DEBUG="false")
        self.assertEqual(disabled.returncode, 0, disabled.stderr)
        self.assertNotIn("+ usermod", disabled.stderr)
        self.assertNotIn("+ install", disabled.stderr)

    def test_zero_and_invalid_ids_are_rejected_before_account_changes(self):
        for field in ("PUID", "PGID"):
            for value in ("0", "00", "-1", "not-a-number"):
                with self.subTest(field=field, value=value):
                    result = self.run_startup(**{field: value})
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse(self.calls.exists())

    def test_root_and_invalid_usernames_are_rejected(self):
        for value in ("root", "bad:name", "bad\nname"):
            with self.subTest(username=value):
                self.assertNotEqual(self.run_startup(USERNAME=value).returncode, 0)
                self.assertFalse(self.calls.exists())

    def test_proxy_mode_needs_no_token_and_preserves_application_output(self):
        result = self.run_startup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Web UI available at http://localhost:8000/", result.stdout)
        self.assertNotIn("--log-to-file", self.calls.read_text())

    def test_mismatched_existing_uid_is_rejected(self):
        self.assertNotEqual(self.run_startup(MOCK_UID="0").returncode, 0)

    def test_missing_or_multiline_password_fails_without_logging_it(self):
        self.assertNotEqual(self.run_startup(USER_PASSWORD_FILE=str(self.temp / "missing")).returncode, 0)
        self.password.write_text(PASSWORD + "\nsecond-line\n")
        result = self.run_startup()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(PASSWORD, result.stdout + result.stderr)

    def test_password_is_optional_and_debug_need_not_be_set(self):
        env = dict(self.env)
        env.pop("DEBUG")
        env.pop("USER_PASSWORD_FILE")
        result = subprocess.run(["bash", str(ENTRYPOINT)], env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.captured_password.exists())


if __name__ == "__main__":
    unittest.main()
