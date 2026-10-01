# MAN IN THE MIDDLE // SUB-LEVEL 29

**Supervisor**: George TOWNLEY (Dept. of Subsystem Routing)
**Assigned Engineer**: Operator (You)
**Security Clearance**: Level 29

---

## 📌 Mission Overview

You have successfully completed the Sub-Level 30 gateway assignment. You are now operating from **Sub-Level 29**, where the security requirements are considerably higher.

## 🛠️ Your Assignment: `task.py`

The Sub-Level 29 web gateway has detected suspicious HTTP requests originating from several internal services. Security suspects that an attacker attempted a **Man-In-The-Middle (MITM)** attack to intercept and manipulate web traffic.

Your job is to inspect each request before it reaches the internal server. The gateway must reject requests that use insecure connections, contain potentially malicious code, or have suspicious **Time To Live (TTL)** values.

Open **`task.py`** and inspect the validation function:

```python
def validate_request(request: dict) -> bool:
```

### Requirements:

1. Each request is a dictionary containing:

   * `"url"`: string (e.g. `"https://internal.company/login"`)
   * `"body"`: string containing the HTTP request body
   * `"ttl"`: integer representing the request's Time To Live
2. A request is **VALID** only if:

   * `request["url"]` starts with `"https://"`
   * `request["body"]` does not contain malicious code such as `"<script>"`, `"javascript:"`, or `"eval("`
   * `request["ttl"]` is between `32` and `128` inclusive
3. Return `True` if the request meets all criteria, otherwise `False`.

### Testing & Execution:

* Click **▶ Run Script** (top right) or type `run task.py` in the terminal below.
* If all 6 verification tests pass, security protocol will escalate your clearance and grant access to the **`level_28`**!
