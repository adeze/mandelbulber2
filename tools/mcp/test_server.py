import asyncio
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

from server import EXAMPLES, REPO, SCENE_LIMIT, Renderer


class RendererTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.scene = self.root / "scene.fract"
        self.scene.write_text("success")
        self.binary = self.root / "renderer"
        self.binary.write_text(f"#!{sys.executable}\n" + '''
import json, pathlib, sys, time
output = pathlib.Path(sys.argv[sys.argv.index("-o") + 1])
output.with_suffix(".json").write_text(json.dumps(sys.argv[1:]))
mode = pathlib.Path(sys.argv[-1]).read_text()
if mode == "wait":
    time.sleep(30)
elif mode == "fail":
    sys.exit(2)
elif mode == "missing":
    pass
elif mode == "invalid":
    output.write_bytes(b"invalid")
else:
    print("x" * 100000)
    output.write_bytes(b"\\x89PNG\\r\\n\\x1a\\nfixture")
''')
        self.binary.chmod(0o700)
        self.renderer = Renderer(self.root, self.binary, timeout=2)

    async def asyncTearDown(self):
        await self.renderer.close()
        self.temp.cleanup()

    async def test_paths_and_bounds(self):
        self.assertEqual(self.renderer.read_scene("scene.fract"), "success")
        (self.root / "escape.fract").symlink_to(Path(__file__))
        (self.root / "large.fract").write_bytes(b"x" * (SCENE_LIMIT + 1))
        for path in [str(Path(__file__)), "escape.fract", "large.fract", "../outside.fract"]:
            with self.subTest(path=path), self.assertRaises((ValueError, OSError)):
                self.renderer.read_scene(path)
        for width, height in [(0, 1), (513, 1), (1, -1), (1, 513)]:
            with self.assertRaises(ValueError):
                await self.renderer.start("scene.fract", width, height)
        with self.assertRaises(ValueError):
            self.renderer.list_examples(limit=101)
        with self.assertRaises(ValueError):
            await self.renderer.cancel("not-my-job")
        (self.root / "build").mkdir()
        (self.root / "build/mcp").symlink_to(self.root.parent, target_is_directory=True)
        with self.assertRaises(ValueError):
            await self.renderer.start("scene.fract", 4, 4)

    async def test_success_and_fixed_command(self):
        result = await self.renderer.start("scene.fract", 16, 12)
        job = self.renderer.get(result["job_id"])
        await job.task
        self.assertEqual(self.renderer.status(result["job_id"])["state"], "completed")
        self.assertEqual(self.renderer.image(result["job_id"]).to_image_content().mimeType, "image/png")
        args = json.loads(job.image.with_suffix(".json").read_text())
        self.assertIn("--never-delete", args)
        self.assertIn("opencl_enabled=false", args)
        self.assertEqual(args[args.index("--logfilepath") + 1], os.devnull)
        self.assertEqual(args[args.index("--res") + 1], "16x12")
        self.assertEqual(job.image.parent.parent.parent, self.root.resolve() / "build/mcp")
        self.assertLessEqual((job.directory / "process.log").stat().st_size, 65536)
        second = await self.renderer.start("scene.fract", 8, 8)
        self.assertNotEqual(second["job_id"], result["job_id"])

    async def test_cancellation_timeout_and_disconnect(self):
        self.scene.write_text("wait")
        result = await self.renderer.start("scene.fract", 4, 4)
        with self.assertRaises(ValueError):
            await self.renderer.start("scene.fract", 4, 4)
        self.assertEqual((await self.renderer.cancel(result["job_id"]))["state"], "cancelled")
        self.assertIsNotNone(self.renderer.get(result["job_id"]).process.returncode)
        self.renderer.timeout = 0.05
        result = await self.renderer.start("scene.fract", 4, 4)
        await self.renderer.get(result["job_id"]).task
        self.assertEqual(self.renderer.status(result["job_id"])["state"], "timed_out")
        result = await self.renderer.start("scene.fract", 4, 4)
        await self.renderer.close()
        self.assertEqual(self.renderer.status(result["job_id"])["state"], "cancelled")

    async def test_failed_and_invalid_images(self):
        for mode, expected in [("fail", "failed"), ("missing", "failed"), ("invalid", "completed")]:
            self.scene.write_text(mode)
            result = await self.renderer.start("scene.fract", 4, 4)
            await self.renderer.get(result["job_id"]).task
            self.assertEqual(self.renderer.status(result["job_id"])["state"], expected)
            with self.assertRaises(ValueError):
                self.renderer.image(result["job_id"])

    @unittest.skipUnless(os.environ.get("MANDELBULBER_MCP_INTEGRATION") == "1", "opt-in real CLI render")
    async def test_official_stdio_real_render(self):
        params = StdioServerParameters(command=sys.executable, args=[str(Path(__file__).with_name("server.py"))])
        async with stdio_client(params) as (read, write):
            async with ClientSession(read, write) as client:
                await client.initialize()
                names = {tool.name for tool in (await client.list_tools()).tools}
                self.assertEqual(names, {"list_examples", "read_scene", "render_preview", "render_status",
                                         "cancel_render", "get_render_image"})
                examples = await client.call_tool("list_examples", {"search": "mandelbulb", "limit": 1})
                self.assertFalse(examples.isError)
                scene = str(EXAMPLES / "mandelbulb power 2.fract")
                if not (REPO / scene).is_file():
                    scene = str(next((REPO / EXAMPLES).glob("mandelbulb*.fract")).relative_to(REPO))
                started = await client.call_tool("render_preview", {"scene_path": scene, "width": 16, "height": 16})
                self.assertFalse(started.isError, started)
                job_id = json.loads(started.content[0].text)["job_id"]
                for _ in range(600):
                    status = await client.call_tool("render_status", {"job_id": job_id})
                    state = json.loads(status.content[0].text)["state"]
                    if state != "running":
                        break
                    await asyncio.sleep(0.2)
                self.assertEqual(state, "completed", status)
                image = await client.call_tool("get_render_image", {"job_id": job_id})
                self.assertFalse(image.isError, image)
                self.assertEqual(image.content[0].type, "image")


if __name__ == "__main__":
    unittest.main()
