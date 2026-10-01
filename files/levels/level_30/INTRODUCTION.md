# INTERNAL ONBOARDING // SUB-LEVEL 30
**Supervisor**: George TOWNLEY (Dept. of Subsystem Routing)  
**Assigned Engineer**: Operator (You)  
**Security Clearance**: Level 30 (Lowest)

---

## 📌 Mission Overview
Welcome to the company! Everyone starts down in Sub-Level 30. Your objective is simple: maintain network integrity and work your way up the 30-folder directory structure to the Root terminal.

## 🛠️ Your First Assignment: `task.py`
The Sub-Level 30 gateway router received telemetry from monitoring probes, but the data stream has corrupted checksums and unauthorized sources.

Open **`task.py`** and inspect the validation function:
```python
def validate_packet(packet: dict) -> bool:
```

### Requirements:
1. Each packet is a dictionary containing:
   - `"id"`: string (e.g. `"SYS-101"`)
   - `"checksum"`: integer
   - `"active"`: boolean
2. A packet is **VALID** only if:
   - `packet["active"]` is `True`
   - `packet["checksum"]` is an **even number** greater than 0 (`checksum > 0 and checksum % 2 == 0`)
   - `packet["id"]` starts with `"SYS-"`
3. Return `True` if the packet meets all criteria, otherwise `False`.

### Testing & Execution:
- Click **▶ Run Script** (top right) or type `run task.py` in the terminal below.
- If all 6 verification tests pass, security protocol will escalate your clearance and grant access to the **`level_29`**!
