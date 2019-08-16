#Tests proper handling of a MeritRemoval when Meros syncs a MeritRemoval of Elements sharing a nonce.

#Types.
from typing import Dict, List, IO, Any

#Transactions class.
from python_tests.Classes.Transactions.Transactions import Transactions

#Consensus classes.
from python_tests.Classes.Consensus.MeritRemoval import SignedMeritRemoval
from python_tests.Classes.Consensus.Consensus import Consensus

#Merit class.
from python_tests.Classes.Merit.Merit import Merit

#TestError Exception.
from python_tests.Tests.TestError import TestError

#Meros classes.
from python_tests.Meros.Meros import MessageType
from python_tests.Meros.RPC import RPC

#JSON standard lib.
import json

def MRSNSyncTest(
    rpc: RPC
) -> None:
    snFile: IO[Any] = open("python_tests/Vectors/Consensus/MeritRemoval/SameNonce.json", "r")
    snVectors: Dict[str, Any] = json.loads(snFile.read())
    #Consensus.
    consensus: Consensus = Consensus(
        bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC")
    )
    removal: SignedMeritRemoval = SignedMeritRemoval.fromJSON(snVectors["removal"])
    consensus.add(removal)
    #Merit.
    merit: Merit = Merit.fromJSON(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
        100,
        Transactions(),
        consensus,
        snVectors["blockchain"]
    )
    snFile.close()

    #Handshake with the node.
    rpc.meros.connect(
        254,
        254,
        len(merit.blockchain.blocks)
    )

    sentLast: bool = False
    hash: bytes = bytes()
    msgs: List[bytes] = []
    ress: List[bytes] = []
    while True:
        msgs.append(rpc.meros.recv())

        if MessageType(msgs[-1][0]) == MessageType.Syncing:
            ress.append(rpc.meros.acknowledgeSyncing())

        elif MessageType(msgs[-1][0]) == MessageType.GetBlockHash:
            height: int = int.from_bytes(msgs[-1][1 : 5], byteorder = "big")
            if height == 0:
                ress.append(rpc.meros.blockHash(merit.blockchain.last()))
            else:
                if height >= len(merit.blockchain.blocks):
                    raise TestError("Meros asked for a Block Hash we do not have.")

                ress.append(rpc.meros.blockHash(merit.blockchain.blocks[height].header.hash))

        elif MessageType(msgs[-1][0]) == MessageType.BlockHeaderRequest:
            hash = msgs[-1][1 : 49]
            for block in merit.blockchain.blocks:
                if block.header.hash == hash:
                    ress.append(rpc.meros.blockHeader(block.header))
                    break

                if block.header.hash == merit.blockchain.last():
                    raise TestError("Meros asked for a Block Header we do not have.")

        elif MessageType(msgs[-1][0]) == MessageType.BlockBodyRequest:
            hash = msgs[-1][1 : 49]
            for block in merit.blockchain.blocks:
                if block.header.hash == hash:
                    ress.append(rpc.meros.blockBody(block.body))
                    break

                if block.header.hash == merit.blockchain.last():
                    raise TestError("Meros asked for a Block Body we do not have.")

        elif MessageType(msgs[-1][0]) == MessageType.ElementRequest:
            sentLast = True
            ress.append(rpc.meros.element(removal))

        elif MessageType(msgs[-1][0]) == MessageType.SyncingOver:
            ress.append(bytes())
            if sentLast:
                break

        else:
            raise TestError("Unexpected message sent: " + msgs[-1].hex().upper())

    #Verify the height.
    if rpc.call("merit", "getHeight") != len(merit.blockchain.blocks):
        raise TestError("Height doesn't match.")

    #Verify the difficulty.
    if merit.blockchain.difficulty != int(rpc.call("merit", "getDifficulty"), 16):
        raise TestError("Difficulty doesn't match.")

    #Verify the blocks.
    for block in merit.blockchain.blocks:
        if rpc.call("merit", "getBlock", [block.header.nonce]) != block.toJSON():
            raise TestError("Block doesn't match.")

    #Verify the Merit Holder height.
    if rpc.call("consensus", "getHeight", [removal.holder.hex()]) != 1:
        raise TestError("Merit Holder height doesn't match.")

    #Verify the Merit Removal.
    if rpc.call("consensus", "getElement", [
        removal.holder.hex(),
        0
    ]) != removal.toJSON():
        raise TestError("Merit Removal doesn't match.")

    #Verify the Live Merit.
    if rpc.call("merit", "getLiveMerit", [removal.holder.hex()]) != 0:
        raise TestError("Live Merit doesn't match.")

    #Verify the Total Merit.
    if rpc.call("merit", "getTotalMerit") != 0:
        raise TestError("Total Merit doesn't match.")

    #Verify the Merit Holder's Merit.
    if rpc.call("merit", "getMerit", [removal.holder.hex()]) != {
        "live": True,
        "malicious": False,
        "merit": 0
    }:
        raise TestError("Merit Holder's Merit doesn't match.")

    #Replay their messages and verify they send what we sent.
    for m in range(0, len(msgs)):
        rpc.meros.send(msgs[m])
        if len(ress[m]) != 0:
            if ress[m] != rpc.meros.recv():
                raise TestError("Invalid sync response.")
