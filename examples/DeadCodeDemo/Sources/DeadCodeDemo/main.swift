struct Calculator {
    func add(_ a: Int, _ b: Int) -> Int { a + b }

    // Intentionally never called — Deadwood/Periphery should flag this.
    func unusedHelper() -> Int { 42 }
}

let calculator = Calculator()
print(calculator.add(1, 2))
