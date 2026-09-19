"""Runtime settings, read once from environment variables."""

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    data_dir: Path
    host: str
    port: int
    go2rtc_api: str
    go2rtc_rtsp: str
    model_path: Path
    segment_seconds: int = 2
    pre_seconds: int = 4
    post_seconds: int = 6
    max_clip_seconds: int = 40

    @property
    def db_path(self) -> Path:
        return self.data_dir / "obscura.db"

    @property
    def clips_dir(self) -> Path:
        return self.data_dir / "clips"

    @property
    def buffer_dir(self) -> Path:
        return self.data_dir / "buffer"

    @property
    def rclone_conf(self) -> Path:
        return self.data_dir / "rclone.conf"


def load() -> Settings:
    data_dir = Path(os.environ.get("OBSCURA_DATA", "./data")).resolve()
    return Settings(
        data_dir=data_dir,
        host=os.environ.get("OBSCURA_HOST", "0.0.0.0"),
        port=int(os.environ.get("OBSCURA_PORT", "7878")),
        go2rtc_api=os.environ.get("OBSCURA_GO2RTC_API", "http://127.0.0.1:1984"),
        go2rtc_rtsp=os.environ.get("OBSCURA_GO2RTC_RTSP", "rtsp://127.0.0.1:8554"),
        model_path=Path(os.environ.get("OBSCURA_MODEL", "/opt/obscura/yolox_nano.onnx")),
    )
