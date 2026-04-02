import Testing
@testable import Recall

@Suite("KeychainHelper", .serialized)
struct KeychainHelperTests {
    private let testKey = "com.recall.test.keychainhelper"

    init() {
        KeychainHelper.delete(key: testKey)
    }

    @Test func saveAndLoad() throws {
        defer { KeychainHelper.delete(key: testKey) }
        try KeychainHelper.save(key: testKey, value: "hello")
        #expect(KeychainHelper.load(key: testKey) == "hello")
    }

    @Test func loadMissingKeyReturnsNil() {
        // init() already deleted the key; no items for this service
        #expect(KeychainHelper.load(key: testKey) == nil)
    }

    @Test func overwriteUpdatesValue() throws {
        defer { KeychainHelper.delete(key: testKey) }
        try KeychainHelper.save(key: testKey, value: "original")
        try KeychainHelper.save(key: testKey, value: "updated")
        #expect(KeychainHelper.load(key: testKey) == "updated")
    }

    @Test func deleteRemovesItem() throws {
        try KeychainHelper.save(key: testKey, value: "value")
        KeychainHelper.delete(key: testKey)
        #expect(KeychainHelper.load(key: testKey) == nil)
    }
}
