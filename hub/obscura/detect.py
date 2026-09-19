"""Motion detection inside zones and person detection (YOLOX-nano, Apache-2.0)."""

import logging
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np

log = logging.getLogger(__name__)

WORK_WIDTH = 320
# Fraction of the zone that must change, per sensitivity level.
MOTION_AREA = {"low": 0.03, "medium": 0.012, "high": 0.004}
PIXEL_DELTA = {"low": 35, "medium": 25, "high": 16}
PERSON_SCORE = {"low": 0.6, "medium": 0.5, "high": 0.4}


def zone_mask(zones: list[dict], kind: str, width: int, height: int) -> np.ndarray:
    """Binary mask of all zones with `kind` enabled. No zones of that kind => whole frame."""
    polys = [z["points"] for z in zones if z.get(kind)]
    if not polys:
        return np.full((height, width), 255, np.uint8)
    mask = np.zeros((height, width), np.uint8)
    for pts in polys:
        arr = np.array([[x * width, y * height] for x, y in pts], np.int32)
        cv2.fillPoly(mask, [arr], 255)
    return mask


def zones_hit(zones: list[dict], kind: str, x: float, y: float) -> list[str]:
    """Names of `kind` zones containing the normalized point (x, y). [] with no zones means 'anywhere'."""
    hits = []
    for z in zones:
        if not z.get(kind):
            continue
        contour = np.array(z["points"], np.float32)
        if cv2.pointPolygonTest(contour, (float(x), float(y)), False) >= 0:
            hits.append(z.get("name") or "zone")
    return hits


class MotionDetector:
    def __init__(self, zones: list[dict], sensitivity: str):
        self.zones = zones
        self.area = MOTION_AREA.get(sensitivity, MOTION_AREA["medium"])
        self.delta = PIXEL_DELTA.get(sensitivity, PIXEL_DELTA["medium"])
        self._bg: np.ndarray | None = None
        self._mask: np.ndarray | None = None
        self._streak = 0
        self.spots: list[list[float]] = []  # centres of the moving areas in the last frame, for the app

    def update(self, frame: np.ndarray) -> float:
        """Returns changed fraction of the motion zone once motion persists for 2 frames, else 0."""
        h, w = frame.shape[:2]
        small = cv2.resize(frame, (WORK_WIDTH, max(1, int(h * WORK_WIDTH / w))))
        gray = cv2.GaussianBlur(cv2.cvtColor(small, cv2.COLOR_BGR2GRAY), (7, 7), 0).astype(np.float32)
        if self._bg is None or self._bg.shape != gray.shape:
            self._bg = gray
            self._mask = zone_mask(self.zones, "motion", gray.shape[1], gray.shape[0])
            return 0.0
        diff = cv2.absdiff(gray, self._bg)
        cv2.accumulateWeighted(gray, self._bg, 0.05)
        changed = (diff > self.delta).astype(np.uint8) * 255
        changed = cv2.bitwise_and(changed, self._mask)
        zone_px = max(1, int(np.count_nonzero(self._mask)))
        fraction = np.count_nonzero(changed) / zone_px
        self.spots = motion_spots(changed) if fraction >= self.area else []
        self._streak = self._streak + 1 if fraction >= self.area else 0
        return fraction if self._streak >= 2 else 0.0


def motion_spots(changed: np.ndarray, limit: int = 6) -> list[list[float]]:
    """[x, y, radius] (normalized) of the largest changed blobs."""
    h, w = changed.shape[:2]
    blobs = cv2.dilate(changed, np.ones((5, 5), np.uint8))
    n, _, stats, centroids = cv2.connectedComponentsWithStats(blobs)
    order = sorted(range(1, n), key=lambda i: -stats[i, cv2.CC_STAT_AREA])[:limit]
    return [[round(float(centroids[i][0]) / w, 3), round(float(centroids[i][1]) / h, 3),
             round(max(float(stats[i, cv2.CC_STAT_WIDTH]), float(stats[i, cv2.CC_STAT_HEIGHT])) / 2 / w, 3)]
            for i in order if stats[i, cv2.CC_STAT_AREA] >= 12]


@dataclass
class Person:
    box: tuple[float, float, float, float]  # normalized x1, y1, x2, y2
    score: float


class PersonDetector:
    SIZE = 416
    STRIDES = (8, 16, 32)

    def __init__(self, model_path: Path):
        import onnxruntime as ort

        opts = ort.SessionOptions()
        opts.intra_op_num_threads = 2
        self.session = ort.InferenceSession(str(model_path), opts, providers=["CPUExecutionProvider"])
        self.input_name = self.session.get_inputs()[0].name
        grids, strides = [], []
        for s in self.STRIDES:
            n = self.SIZE // s
            ys, xs = np.meshgrid(np.arange(n), np.arange(n), indexing="ij")
            grids.append(np.stack((xs, ys), 2).reshape(-1, 2))
            strides.append(np.full((n * n, 1), s))
        self._grid = np.concatenate(grids).astype(np.float32)
        self._stride = np.concatenate(strides).astype(np.float32)

    def detect(self, frame: np.ndarray, min_score: float) -> list[Person]:
        h, w = frame.shape[:2]
        r = min(self.SIZE / h, self.SIZE / w)
        padded = np.full((self.SIZE, self.SIZE, 3), 114, np.uint8)
        padded[: int(h * r), : int(w * r)] = cv2.resize(frame, (int(w * r), int(h * r)))
        blob = padded.transpose(2, 0, 1)[None].astype(np.float32)
        out = self.session.run(None, {self.input_name: blob})[0][0]

        xy = (out[:, :2] + self._grid) * self._stride
        wh = np.exp(out[:, 2:4]) * self._stride
        scores = out[:, 4] * out[:, 5]  # objectness * class 0 ("person")
        keep = scores >= min_score
        if not keep.any():
            return []
        xy, wh, scores = xy[keep] / r, wh[keep] / r, scores[keep]
        boxes = np.concatenate((xy - wh / 2, wh), 1)  # x, y, w, h for NMSBoxes
        idx = cv2.dnn.NMSBoxes(boxes.tolist(), scores.tolist(), min_score, 0.45)
        people = []
        for i in np.array(idx).flatten():
            x, y, bw, bh = (float(v) for v in boxes[i])
            people.append(Person(
                (max(0.0, x / w), max(0.0, y / h), min(1.0, (x + bw) / w), min(1.0, (y + bh) / h)),
                float(scores[i]),
            ))
        return people


def load_person_detector(model_path: Path) -> PersonDetector | None:
    if not model_path.exists():
        log.warning("person model not found at %s; person detection disabled", model_path)
        return None
    try:
        return PersonDetector(model_path)
    except Exception:  # broken model file or unsupported CPU: keep motion working
        log.exception("failed to load person model")
        return None
