from task import validate_packet

def run_tests():
    test_cases = [
        ({"id": "SYS-101", "checksum": 42, "active": True}, True, "Valid packet"),
        ({"id": "SYS-999", "checksum": 13, "active": True}, False, "Odd checksum should fail"),
        ({"id": "SYS-002", "checksum": -4, "active": True}, False, "Negative checksum should fail"),
        ({"id": "SYS-004", "checksum": 0, "active": True}, False, "Zero checksum should fail"),
        ({"id": "USR-101", "checksum": 42, "active": True}, False, "ID must start with SYS-"),
        ({"id": "SYS-888", "checksum": 24, "active": False}, False, "Inactive packet should fail")
    ]
    for pkt, expected, desc in test_cases:
        if validate_packet(pkt) != expected:
            return False
    return True

if __name__ == '__main__':
    run_tests()
