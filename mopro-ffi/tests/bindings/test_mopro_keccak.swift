import mopro
import Foundation

let moproCircom = MoproCircom()

let wasmPath = "./../../../../mopro-core/examples/circom/keccak256/target/keccak256_256_test_js/keccak256_256_test.wasm"
let r1csPath = "./../../../../mopro-core/examples/circom/keccak256/target/keccak256_256_test.r1cs"

// Helper function to convert bytes to bits
func bytesToBits(bytes: [UInt8]) -> [Int32] {
    var bits = [Int32]()
    for byte in bytes {
        for j in 0..<8 {
            let bit = (byte >> j) & 1
            bits.append(Int32(bit))
        }
    }
    return bits
}

// TODO: should handle 254-bit input
func serializeOutputs(_ int32Array: [Int32]) -> [UInt8] {
    var bytesArray: [UInt8] = []
    let length = int32Array.count
    var littleEndianLength = length.littleEndian
    let targetLength = 32
    withUnsafeBytes(of: &littleEndianLength) {
        bytesArray.append(contentsOf: $0)
    }
    for value in int32Array {
        var littleEndian = value.littleEndian
        var byteLength = 0
        withUnsafeBytes(of: &littleEndian) {
            bytesArray.append(contentsOf: $0)
            byteLength = byteLength + $0.count
        }
        if byteLength < targetLength {
            let paddingCount = targetLength - byteLength
            let paddingArray = [UInt8](repeating: 0, count: paddingCount)
            bytesArray.append(contentsOf: paddingArray)
        } 
    }
    return bytesArray
}

do {
    // Setup
    let setupResult = try moproCircom.setup(wasmPath: wasmPath, r1csPath: r1csPath)
    assert(!setupResult.provingKey.isEmpty, "Proving key should not be empty")

    // Prepare inputs
    let inputVec: [UInt8] = [
        116, 101, 115, 116, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0,
    ]
    let bits = bytesToBits(bytes: inputVec)
    var inputs = [String: [Int32]]()
    inputs["in"] = bits

    // Expected outputs
    let outputVec: [UInt8] = [
        37, 17, 98, 135, 161, 178, 88, 97, 125, 150, 143, 65, 228, 211, 170, 133, 153, 9, 88,
        212, 4, 212, 175, 238, 249, 210, 214, 116, 170, 85, 45, 21,
    ]
    let outputBits: [Int32] = bytesToBits(bytes: outputVec)
    let expectedOutput: [UInt8] = serializeOutputs(outputBits)

    // Generate Proof
    let generateProofResult = try moproCircom.generateProof(circuitInputs: inputs)
    assert(!generateProofResult.proof.isEmpty, "Proof should not be empty")

    // Verify Proof
    assert(Data(expectedOutput) == generateProofResult.inputs, "Circuit outputs mismatch the expected outputs")

    let isValid = try moproCircom.verifyProof(proof: generateProofResult.proof, publicInput: generateProofResult.inputs)
    assert(isValid, "Proof verification should succeed")

} catch let error as MoproError {
    print("MoproError: \(error)")
} catch {
    print("Unexpected error: \(error)")
}
