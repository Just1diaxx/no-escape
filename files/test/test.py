import math
import sys
from dataclasses import dataclass, field
from collections import Counter, deque

# =============================================================================
# 1. CORE MT19937 IMPLEMENTATION (BITWISE AND ARITHMETIC BENCHMARK)
# =============================================================================

class MersenneTwister32:
    """
    Bit-for-bit implementation of the MT19937 PRNG algorithm.
    Validates bitwise operations, integer masking, and overflow handling.
    """
    def __init__(self, seed_val: int = 5489):
        self.mt = [0] * 624
        self.index = 624
        self.seed(seed_val)

    def seed(self, s: int) -> None:
        self.mt[0] = s & 0xFFFFFFFF
        for i in range(1, 624):
            prev = self.mt[i - 1]
            # Multi-term arithmetic and bitwise XOR to test operator precedence
            self.mt[i] = (1812433253 * (prev ^ (prev >> 30)) + i) & 0xFFFFFFFF
        self.index = 624

    def extract_number(self) -> int:
        if self.index >= 624:
            self.twist()
        
        y = self.mt[self.index]
        y ^= (y >> 11)
        y ^= ((y << 7) & 0x9D2C5680) & 0xFFFFFFFF
        y ^= ((y << 15) & 0xEFC60000) & 0xFFFFFFFF
        y ^= (y >> 18)
        
        self.index += 1
        return y & 0xFFFFFFFF

    def twist(self) -> None:
        for i in range(624):
            # Binary masking across 32-bit boundary
            y = ((self.mt[i] & 0x80000000) + (self.mt[(i + 1) % 624] & 0x7FFFFFFF)) & 0xFFFFFFFF
            self.mt[i] = (self.mt[(i + 397) % 624] ^ (y >> 1)) & 0xFFFFFFFF
            if y & 1:
                self.mt[i] = (self.mt[i] ^ 0x9908B0DF) & 0xFFFFFFFF
        self.index = 0

    def genrand_res53(self) -> float:
        # Generates a 53-bit resolution floating point value
        a = self.extract_number() >> 5
        b = self.extract_number() >> 6
        return (float(a) * 67108864.0 + float(b)) * (1.0 / 9007199254740992.0)

    def randint(self, a: int, b: int) -> int:
        return a + int(math.floor(self.genrand_res53() * float(b - a + 1)))

    def uniform(self, a: float, b: float) -> float:
        return a + (b - a) * self.genrand_res53()

    def choice(self, sequence):
        if not sequence: return None
        return sequence[int(math.floor(self.genrand_res53() * float(len(sequence))))]


# Deterministic drop-in replacement for the standard random module
class MockRandomModule:
    def __init__(self): self._engine = MersenneTwister32(42)
    def seed(self, val): self._engine.seed(val)
    def randint(self, a, b): return self._engine.randint(a, b)
    def uniform(self, a, b): return self._engine.uniform(a, b)
    def choice(self, seq): return self._engine.choice(seq)

random = MockRandomModule()

# =============================================================================
# 2. BUSINESS LOGIC (DATACLASSES, INHERITANCE & NESTED STRUCTURES)
# =============================================================================

@dataclass
class Item:
    name: str
    value: int
    weight: float
    category: str

# Base entity class validating OOP hierarchy and method resolution
class Entity:
    def __init__(self, name: str):
        self.name = name
    def get_type(self) -> str:
        return "GenericEntity"

@dataclass
class Robot(Entity):
    battery: int = 100
    health: int = 100
    inventory: list = field(default_factory=list)
    position: tuple = (0, 0)
    tasks_completed: int = 0

    def __post_init__(self):
        Entity.__init__(self, self.name)

    def move(self, x: int, y: int) -> None:
        curr_x, curr_y = self.position
        distance = abs(curr_x - x) + abs(curr_y - y)
        cost = distance * 3

        if cost > self.battery:
            raise RuntimeError(f"Low Energy: Required {cost}, Available {self.battery}")

        self.battery -= cost
        self.position = (x, y)

    def recharge(self, amount: int = 100) -> None:
        self.battery = min(100, self.battery + amount)

    def collect(self, item: Item) -> None:
        self.inventory.append(item)
        self.tasks_completed += 1

    def inventory_value(self) -> int:
        return sum(i.value for i in self.inventory)

    def status(self) -> str:
        return f"[{Entity.get_type(self)}] {self.name} | Bat: {self.battery}% | Items: {len(self.inventory)}"


# =============================================================================
# 3. COMPUTATIONAL PIPELINE (LIST COMPREHENSIONS & GENERATORS)
# =============================================================================

def generate_items(n: int) -> list:
    categories = ["tool", "material", "data", "energy"]
    names = ["wrench", "bolt", "chip", "core", "plate", "wire", "lens"]
    return [
        Item(
            name=f"{random.choice(names)}_{i}",
            value=random.randint(15, 120),
            weight=round(random.uniform(0.2, 7.5), 2),
            category=random.choice(categories)
        )
        for i in range(n)
    ]

def run_mission(robot: Robot, waypoints: list, items: list) -> list:
    print(f"--- STARTING SIMULATION FOR {robot.name.upper()} ---")
    collected = []
    
    for idx, (x, y) in enumerate(waypoints):
        print(f"Step {idx}: Target -> ({x}, {y})")
        try:
            try:
                robot.move(x, y)
            except RuntimeError as node_err:
                print(f"  [Warning] {node_err}. Attempting recovery routine...")
                robot.recharge(60)
                robot.move(x, y)
                
            if idx < len(items):
                target_item = items[idx]
                robot.collect(target_item)
                collected.append(target_item)
                print(f"  -> Successfully secured: {target_item.name} (Val: {target_item.value})")
        except RuntimeError as critical_err:
            print(f"  [Critical] Waypoint ({x}, {y}) unfeasible: {critical_err}")
            print("  Skipping to next node.")
            
    return collected

# =============================================================================
# 4. EXECUTION ENTRYPOINT & VALIDATION SUITE
# =============================================================================

if __name__ == "__main__":
    # Force deterministic seed for reproducible numeric comparisons
    random.seed(1337)

    # Instantiate robot and generate test inventory
    scout = Robot(name="X-Walker")
    loot_pool = generate_items(12)
    
    # Generate random coordinate waypoints via list comprehension
    nodes = [(random.randint(0, 8), random.randint(0, 8)) for _ in range(10)]

    # Execute primary mission simulation
    retrieved = run_mission(scout, nodes, loot_pool)

    # Output robot diagnostics and summary telemetry
    print("\n" + "="*40)
    print(scout.status())
    print(f"Final Inventory Worth: {scout.inventory_value()} credits")
    print(f"Total Successful Operations: {scout.tasks_completed}")
    print("="*40)

    # Collection validation: Counter mapping frequencies and dictionary conversion
    freq_map = Counter(obj.category for obj in retrieved)
    print(f"Density Metric (Counter): {dict(freq_map)}")

    # Mathematical stress test: Mean and standard deviation calculations
    item_credits = [obj.value for obj in retrieved]
    mean_val = 0.0
    sigma = 0.0
    if item_credits:
        n_elements = len(item_credits)
        mean_val = sum(item_credits) / n_elements
        variance_sum = sum((val - mean_val) ** 2 for val in item_credits)
        sigma = math.sqrt(variance_sum / n_elements)
        print(f"Statistical Delta: Mean={mean_val:.2f}, StdDev={sigma:.4f}")

    # Deque validation: Sliding buffer with maximum length constraint
    telemetry_log = deque(maxlen=4)
    for obj in retrieved:
        telemetry_log.append(obj.name)
    print(f"Sliding Telemetry Buffer (Last 4): {list(telemetry_log)}")

    # Specific test validations
    print("\n" + "─"*40)
    print("RUNNING EXPLICIT VERIFICATION CHECKS:")
    tests_passed = 0
    total_tests = 7

    # Check 1: Robot name and entity type
    if scout.name == "X-Walker" and scout.get_type() == "GenericEntity":
        print("  [✔ PASS] Test 1: Robot instance identity and inheritance resolution verified.")
        tests_passed += 1
    else:
        print("  [✖ FAIL] Test 1: Entity identity mismatch.")

    # Check 2: Mission tasks completed
    if scout.tasks_completed == 10 and len(retrieved) == 10:
        print("  [✔ PASS] Test 2: Mission waypoint processing and item retrieval verified.")
        tests_passed += 1
    else:
        print("  [✖ FAIL] Test 2: Waypoint task count mismatch.")

    # Check 3: Inventory value
    if scout.inventory_value() == 657:
        print("  [✔ PASS] Test 3: Inventory valuation sum calculation verified (657 credits).")
        tests_passed += 1
    else:
        print(f"  [✖ FAIL] Test 3: Valuation mismatch (expected 657, got {scout.inventory_value()}).")

    # Check 4: Category frequencies
    expected_categories = {"material": 1, "energy": 3, "data": 3, "tool": 3}
    if dict(freq_map) == expected_categories:
        print("  [✔ PASS] Test 4: Counter categorization frequency distribution verified.")
        tests_passed += 1
    else:
        print("  [✖ FAIL] Test 4: Category frequency mismatch.")

    # Check 5: Statistical mean
    if round(mean_val, 2) == 65.70 and round(sigma, 4) == 34.8340:
        print("  [✔ PASS] Test 5: Mathematical mean (65.70) and standard deviation (34.8340) verified.")
        tests_passed += 1
    else:
        print(f"  [✖ FAIL] Test 5: Statistical calculation mismatch (got {mean_val:.2f}, {sigma:.4f}).")

    # Check 6: Sliding buffer constraint
    expected_buffer = ["core_6", "core_7", "chip_8", "wire_9"]
    if list(telemetry_log) == expected_buffer and len(telemetry_log) == 4:
        print("  [✔ PASS] Test 6: Deque sliding window buffer maxlen=4 constraint verified.")
        tests_passed += 1
    else:
        print("  [✖ FAIL] Test 6: Sliding buffer contents mismatch.")

    # Check 7: Battery level after recovery
    if scout.battery == 25:
        print("  [✔ PASS] Test 7: Battery depletion and runtime recovery balance verified (25%).")
        tests_passed += 1
    else:
        print(f"  [✖ FAIL] Test 7: Unexpected battery state ({scout.battery}%).")

    print("─"*40)
    if tests_passed == total_tests:
        print("All tests passed.")
    else:
        print(f"Verification incomplete: {tests_passed}/{total_tests} passed.")
