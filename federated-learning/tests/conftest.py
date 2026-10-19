import sys
from pathlib import Path

FL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(FL / "functions-ml"))
sys.path.insert(0, str(FL / "scripts"))
