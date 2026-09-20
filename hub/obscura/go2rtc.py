"""Thin client for the local go2rtc sidecar (bound to 127.0.0.1, never exposed)."""

import contextlib
import logging

import httpx

log = logging.getLogger(__name__)


def stream_names(cam_id: int) -> tuple[str, str]:
    """Names are derived from the numeric id only, so no user input reaches go2rtc paths."""
    return f"cam_{cam_id}", f"cam_{cam_id}_sub"


class Go2rtc:
    def __init__(self, api: str, rtsp: str):
        self.api, self.rtsp = api.rstrip("/"), rtsp.rstrip("/")
        self.client = httpx.AsyncClient(base_url=self.api, timeout=httpx.Timeout(10, read=None))

    def rtsp_url(self, name: str) -> str:
        return f"{self.rtsp}/{name}"

    async def register(self, cam_id: int, main_url: str, sub_url: str | None, talk_url: str | None = None) -> None:
        """talk_url: extra source that carries two-way audio (Tapo's own protocol). go2rtc opens it only
        when something is played into the camera; video keeps coming from RTSP."""
        main, sub = stream_names(cam_id)
        main_srcs = [main_url, talk_url] if talk_url else [main_url]
        for name, srcs in ((main, main_srcs), (sub, [sub_url or main_url])):
            r = await self.client.put("/api/streams", params=[("name", name)] + [("src", s) for s in srcs])
            # go2rtc runs without a config file on purpose (credentials stay in memory), so it
            # answers "config file disabled" after creating the stream. That is success.
            if r.status_code >= 400 and "config file disabled" not in r.text:
                log.warning("go2rtc register %s failed: %s", name, r.text[:200])

    async def unregister(self, cam_id: int) -> None:
        """Best effort: a stream that go2rtc no longer knows about is already gone."""
        for name in stream_names(cam_id):
            try:
                await self.client.delete("/api/streams", params={"src": name})
            except httpx.HTTPError as exc:
                log.warning("go2rtc unregister %s failed: %s", name, exc)

    async def frame(self, cam_id: int) -> bytes | None:
        r = await self.client.get("/api/frame.jpeg", params={"src": stream_names(cam_id)[0]},
                                  timeout=15)
        return r.content if r.status_code == 200 else None

    def mp4_request(self, cam_id: int, sub: bool, audio: bool = False) -> httpx.Request:
        name = stream_names(cam_id)[1 if sub else 0]
        src = name
        if audio:
            # Cameras send G.711 (PCMA/PCMU), which plain MP4 cannot carry. go2rtc can repack it as
            # FLAC, but Android's player stays silent on FLAC-in-MP4 and the FLAC encoder in go2rtc
            # 1.9.14 can crash the process when a viewer disconnects. Transcode to AAC instead, the
            # codec the clips already use; the video track is copied. go2rtc starts this ffmpeg
            # source when the first viewer asks for sound and stops it when the last one leaves.
            src = f"ffmpeg:{name}#video=copy#audio=aac"
        return self.client.build_request("GET", "/api/stream.mp4", params={"src": src})

    async def play(self, cam_id: int, src: str) -> None:
        """Play audio into the camera's speaker (go2rtc "stream to camera")."""
        r = await self.client.post("/api/streams", params={"dst": stream_names(cam_id)[0], "src": src}, timeout=15)
        if r.status_code >= 400:
            raise RuntimeError(r.text[:200] or f"go2rtc error {r.status_code}")

    async def stop_play(self, cam_id: int) -> None:
        """An empty source stops whatever the camera is playing."""
        with contextlib.suppress(httpx.HTTPError):
            await self.client.post("/api/streams", params={"dst": stream_names(cam_id)[0], "src": ""})
