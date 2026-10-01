# task.py - Sub-Level 30 Security Gateway Telemetry Validator
# Assigned to: Operator
# Supervisor: George TOWNLEY

def validate_packet(packet: dict) -> bool:
    """
    Validates an incoming system telemetry packet.
    
    Rules:
    - Must be active: packet['active'] == True
    - Checksum must be positive and even: packet['checksum'] > 0 and packet['checksum'] % 2 == 0
    - ID must start with 'SYS-': packet['id'].startswith('SYS-')
    """
    # TODO: Implement the validation logic below!
    # Currently it rejects everything by default.

    
    return False