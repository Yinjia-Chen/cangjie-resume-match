"""Exercise real Docling option types across hosts without invoking native OCR APIs."""
import importlib.util
import os
import unittest
from pathlib import Path
from unittest.mock import patch

# Import native dependencies on the actual host before simulating another host.
# platform is a shared module: patching it during a first torch import changes its loader.
from docling.datamodel import pipeline_options  # noqa: F401

spec = importlib.util.spec_from_file_location("docling_bridge", Path(__file__).resolve().parents[1] / "src/resume_parser/docling_bridge.py")
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


class OcrOptionsTest(unittest.TestCase):
    def options(self, host, engine="auto", image=False):
        with patch.dict(os.environ, {"RESUME_MATCH_OCR": engine}), patch.object(bridge.platform, "system", return_value=host):
            return bridge.ocr_options(image)

    def test_mac_default_preserves_native_language_tags(self):
        options = self.options("Darwin", image=True)
        self.assertEqual(options.kind, "ocrmac")
        self.assertEqual(options.lang, ["zh-Hans", "en-US"])
        self.assertTrue(options.force_full_page_ocr)

    def test_linux_default_uses_tesseract_cli_language_codes(self):
        options = self.options("Linux")
        self.assertEqual(options.kind, "tesseract")
        self.assertEqual(options.lang, ["chi_sim", "eng"])
        self.assertFalse(options.force_full_page_ocr)

    def test_tesseract_can_be_selected_on_mac(self):
        self.assertTrue(self.options("Darwin", "tesseract", True).force_full_page_ocr)

    def test_apple_engine_is_rejected_on_linux(self):
        with self.assertRaisesRegex(ValueError, "requires macOS"):
            self.options("Linux", "ocrmac")

    def test_unknown_engine_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Unsupported"):
            self.options("Linux", "invalid")


if __name__ == "__main__":
    unittest.main()
