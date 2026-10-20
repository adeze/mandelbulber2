"""Local CLI bridge. Scene files must be trusted: this is not a renderer sandbox."""

import asyncio
from contextlib import asynccontextmanager
from dataclasses import dataclass
import os
from pathlib import Path
import signal
from typing import Annotated
from uuid import uuid4

import anyio
from mcp.server.fastmcp import FastMCP, Image
from pydantic import Field

REPO = Path(__file__).resolve().parents[2]
EXAMPLES = Path("mandelbulber2/deploy/share/mandelbulber2/examples")
SCENE_LIMIT = 2 * 1024 * 1024
IMAGE_LIMIT = 8 * 1024 * 1024
LOG_LIMIT = 64 * 1024
TERMINAL = {"completed", "failed", "cancelled", "timed_out"}


@dataclass
class Job:
    directory: Path
    state: str = "running"
    returncode: int | None = None
    process: asyncio.subprocess.Process | None = None
    task: asyncio.Task | None = None

    @property
    def image(self) -> Path:
        return self.directory / "preview.png"


class Renderer:
    def __init__(self, root: Path = REPO, binary: Path | None = None, timeout: float = 120):
        self.root = root.resolve()
        self.binary = binary
        self.timeout = timeout
        self.jobs: dict[str, Job] = {}
        self.lock = asyncio.Lock()
        self.session: Path | None = None

    def scene(self, path: str) -> Path:
        candidate = (self.root / path).resolve(strict=True)
        if not candidate.is_relative_to(self.root) or candidate.suffix.lower() != ".fract":
            raise ValueError("Scene must be a .fract file inside the repository")
        if not candidate.is_file() or candidate.stat().st_size > SCENE_LIMIT:
            raise ValueError("Scene must be a regular file no larger than 2 MiB")
        return candidate

    def read_scene(self, path: str) -> str:
        with self.scene(path).open("rb") as stream:
            data = stream.read(SCENE_LIMIT + 1)
        if len(data) > SCENE_LIMIT:
            raise ValueError("Scene exceeds 2 MiB")
        return data.decode("utf-8")

    def list_examples(self, search: str = "", limit: int = 20) -> list[str]:
        if not 1 <= limit <= 100:
            raise ValueError("limit must be between 1 and 100")
        matches = []
        for path in sorted((self.root / EXAMPLES).rglob("*.fract")):
            if search.casefold() in path.name.casefold():
                try:
                    self.scene(str(path))
                except (ValueError, OSError):
                    continue
                matches.append(str(path.relative_to(self.root)))
                if len(matches) == limit:
                    break
        return matches

    def executable(self) -> Path:
        candidates = [self.binary] if self.binary else [
            self.root / "build" / variant / "bin/mandelbulber2.app/Contents/MacOS/mandelbulber2"
            for variant in ("qt6-release", "qt6-debug")
        ]
        for path in candidates:
            if path and path.is_file() and os.access(path, os.X_OK):
                return path.resolve()
        raise ValueError("Build the Qt6 Release or Debug application before rendering")

    async def start(self, scene_path: str, width: int, height: int) -> dict:
        if not (1 <= width <= 512 and 1 <= height <= 512):
            raise ValueError("width and height must each be between 1 and 512")
        scene = self.scene(scene_path)
        binary = self.executable()
        async with self.lock:
            if any(job.state not in TERMINAL for job in self.jobs.values()):
                raise ValueError("A render is already active; wait or cancel it first")
            if self.session is None:
                base = (self.root / "build/mcp").resolve()
                if not base.is_relative_to(self.root):
                    raise ValueError("Render output directory must remain inside the repository")
                self.session = base / uuid4().hex
                self.session.mkdir(parents=True, exist_ok=False)
            job_id = uuid4().hex
            job = Job(self.session / job_id)
            job.directory.mkdir()
            # Snapshot the bounded input so later edits cannot change the queued scene.
            snapshot = job.directory / "scene.fract"
            snapshot.write_text(self.read_scene(str(scene)), encoding="utf-8")
            command = [str(binary), "--nogui", "--never-delete", "--no-cli-color",
                       "--format", "png", "--res", f"{width}x{height}",
                       "--override", "opencl_enabled=false", "--logfilepath",
                       os.devnull, "-o", str(job.image), str(snapshot)]
            env = {**os.environ, "QT_QPA_PLATFORM": "offscreen"}
            job.process = await asyncio.create_subprocess_exec(
                *command, cwd=self.root, env=env, start_new_session=True,
                stdin=asyncio.subprocess.DEVNULL,
                stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT)
            self.jobs[job_id] = job
            job.task = asyncio.create_task(self.watch(job))
            return {"job_id": job_id, **self.status(job_id)}

    async def drain_log(self, job: Job):
        written = 0
        with (job.directory / "process.log").open("wb") as log:
            while chunk := await job.process.stdout.read(8192):
                remaining = max(0, LOG_LIMIT - written)
                log.write(chunk[:remaining])
                written += min(len(chunk), remaining)

    async def stop_process(self, job: Job):
        if job.process and job.process.returncode is None:
            try:
                os.killpg(job.process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            await job.process.wait()

    async def watch(self, job: Job):
        drain = asyncio.create_task(self.drain_log(job))
        try:
            await asyncio.wait_for(job.process.wait(), timeout=self.timeout)
            job.returncode = job.process.returncode
            if job.state == "running":
                job.state = "completed" if job.process.returncode == 0 and job.image.is_file() else "failed"
        except TimeoutError:
            await self.stop_process(job)
            job.returncode = job.process.returncode
            job.state = "timed_out"
        except asyncio.CancelledError:
            job.state = "cancelled"
            await self.stop_process(job)
            raise
        finally:
            await drain
            job.returncode = job.process.returncode

    def get(self, job_id: str) -> Job:
        if job_id not in self.jobs:
            raise ValueError("Unknown job_id for this server session")
        return self.jobs[job_id]

    def status(self, job_id: str) -> dict:
        job = self.get(job_id)
        log = job.directory / "process.log"
        return {"state": job.state, "returncode": job.returncode,
                "log": log.read_bytes()[-4096:].decode("utf-8", errors="replace") if log.exists() else ""}

    async def cancel(self, job_id: str) -> dict:
        job = self.get(job_id)
        if job.state not in TERMINAL:
            await self.stop_process(job)
            job.returncode = job.process.returncode
            job.state = "cancelled"
            await job.task
        return self.status(job_id)

    def image(self, job_id: str) -> Image:
        job = self.get(job_id)
        if job.state != "completed" or not job.image.is_file():
            raise ValueError("Render has no completed image")
        with job.image.open("rb") as stream:
            data = stream.read(IMAGE_LIMIT + 1)
        if len(data) > IMAGE_LIMIT or not data.startswith(b"\x89PNG\r\n\x1a\n"):
            raise ValueError("Render output must be a PNG no larger than 8 MiB")
        return Image(data=data, format="png")

    async def close(self):
        for job_id, job in self.jobs.items():
            if job.state not in TERMINAL:
                await self.cancel(job_id)
        await asyncio.gather(*(job.task for job in self.jobs.values()), return_exceptions=True)


renderer = Renderer()


@asynccontextmanager
async def lifespan(_server):
    try:
        yield {}
    finally:
        with anyio.CancelScope(shield=True):
            await renderer.close()


mcp = FastMCP("Mandelbulber Local CPU Preview", lifespan=lifespan,
              instructions="Local trusted repository scenes only. CPU CLI renders; no live GUI control or Metal backend.")


@mcp.tool()
def list_examples(search: str = "", limit: Annotated[int, Field(ge=1, le=100)] = 20) -> list[str]:
    """List repository example scene paths, optionally filtering names."""
    return renderer.list_examples(search, limit)


@mcp.tool()
def read_scene(path: str) -> str:
    """Read raw trusted .fract text inside this repository (maximum 2 MiB)."""
    return renderer.read_scene(path)


@mcp.tool()
async def render_preview(scene_path: str, width: Annotated[int, Field(ge=1, le=512)] = 256,
                         height: Annotated[int, Field(ge=1, le=512)] = 256) -> dict:
    """Start one trusted local scene as a bounded CPU PNG job; returns a session job_id."""
    return await renderer.start(scene_path, width, height)


@mcp.tool()
def render_status(job_id: str) -> dict:
    """Get this session's render state, exit code and bounded diagnostic log."""
    return renderer.status(job_id)


@mcp.tool()
async def cancel_render(job_id: str) -> dict:
    """Cancel only a render started by this server session and reap its process."""
    return await renderer.cancel(job_id)


@mcp.tool()
def get_render_image(job_id: str) -> Image:
    """Return the PNG image from a successfully completed session job."""
    return renderer.image(job_id)


if __name__ == "__main__":
    mcp.run(transport="stdio")
