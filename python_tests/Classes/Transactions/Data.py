# pyright: strict

#Types.
from typing import Dict, Tuple, Any

#SpamFilter class.
from python_tests.Classes.Transactions.SpamFilter import SpamFilter

#Ed25519 lib.
import ed25519

#Blake2b standard function.
from hashlib import blake2b

#Data class.
class Data:
    #Constructor.
    def __init__(
        self,
        input: bytes,
        data: bytes,
        signature: bytes = bytes(64),
        proof: int = 0
    ) -> None:
        self.input: bytes = input
        self.data: bytes = data
        self.hash: bytes = blake2b(
            b"\3" + input + data,
            digest_size = 48
        ).digest()

        self.signature: bytes = signature
        self.proof: int = proof

    #Sign.
    def sign(
        self,
        privKey: bytes
    ) -> None:
        self.signature: bytes = ed25519.SigningKey(privKey).sign(b"MEROS" + self.hash)

    #Mine.
    def beat(
        self,
        filter: SpamFilter
    ) -> None:
        result: Tuple[bytes, int] = filter.beat(self.hash)
        self.argon: bytes = result[0]
        self.proof: int = result[1]

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        return (
            self.input +
            len(self.data).to_bytes(1, byteorder="big") +
            self.data +
            self.signature +
            self.proof.to_bytes(4, byteorder="big")
        )

    #Data -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "descendant": "data",
            "inputs": [
                {
                    "hash": self.input.hex().upper()
                }
            ],
            "outputs": [],
            "hash": self.hash.hex().upper(),

            "data": self.data.hex().upper(),
            "signature": self.signature.hex().upper(),
            "proof": self.proof,
            "argon": self.argon.hex().upper()
        }

    #JSON -> Data.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        return Data(
            bytes.fromhex(json["inputs"][0]["hash"]),
            bytes.fromhex(json["data"]),
            bytes.fromhex(json["signature"]),
            json["proof"]
        )