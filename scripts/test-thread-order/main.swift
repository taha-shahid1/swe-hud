// Self-check for ThreadStore ordering. Run (scratch home keeps real threads untouched):
// swiftc -o /tmp/order-check Sources/HUD/ThreadItem.swift Sources/HUD/ThreadStore.swift scripts/test-thread-order/main.swift && CFFIXED_USER_HOME=$(mktemp -d) /tmp/order-check
import Foundation

let store = ThreadStore()
let a = store.add(key: "", title: "a"), b = store.add(key: "", title: "b"), c = store.add(key: "", title: "c")
let d = store.add(key: "", title: "d")
store.setStatus(d.id, status: .needsYou)
func titles() -> String { store.sorted.map(\.title).joined() }

assert(titles() == "dabc")             // needs-you group first, then creation order
store.move(c.id, by: -1); assert(titles() == "dacb")
store.move(c.id, by: -1); assert(titles() == "dcab")
store.move(c.id, by: -1); assert(titles() == "dcab") // won't cross into the needs-you group
store.move(a.id, to: b.id); assert(titles() == "dcba") // drag down: lands below target
store.move(b.id, to: c.id); assert(titles() == "dbca") // drag up: lands above target
store.move(d.id, to: a.id); assert(titles() == "dbca") // different group: no-op
assert(ThreadStore().sorted.map(\.title).joined() == "dbca") // order persists
print("ok")
