#Errors lib.
import ../../lib/Errors

#Import the numerical libraries.
import ../../lib/BN
import ../../lib/Base

#Import the Time library.
import ../../lib/Time

#Import the hashing libraries.
import ../../lib/SHA512
import ../../lib/Argon

#Import the Wallet libraries.
import ../../Wallet/Address
import ../../Wallet/Wallet

#Import the Serialization library.
import ../../Network/Serialize/SerializeMiners
import ../../Network/Serialize/SerializeBlock

#Import the Merkle library and BlockObj.
import Merkle
import objects/BlockObj
#Export the BlockObj.
export BlockObj

#String utils standard library.
import strutils

#New Block function. Creates a new block. Raises an error if there's an issue.
proc newBlock*(
    last: string,
    nonce: BN,
    time: BN,
    validations: seq[tuple[validator: string, start: int, last: int]],
    merkle: MerkleTree,
    publisher: string,
    proof: BN,
    miners: seq[tuple[miner: string, amount: int]],
    signature: string
): Block {.raises: [ResultError, ValueError, Exception].} =
    #Verify the arguments.
    #Validations.
    for validation in validations:
        if Address.verify(validation.validator) == false:
            raise newException(ValueError, "Invalid address.")
        if validation.start < 0:
            raise newException(ValueError, "Invalid start.")
        if validation.last < 0:
            raise newException(ValueError, "Invalid last.")
    #Miners.
    var
        total: int = 0
    for miner in miners:
        total += miner.amount
        if Address.verify(miner.miner) == false:
            raise newException(ValueError, "Invalid address.")
        if (miner.amount < 1) or (1000 < miner.amount):
            raise newException(ValueError, "Invalid amount.")
    if total != 1000:
        raise newException(ValueError, "Invalid total amount.")

    #Ceate the block.
    result = newBlockObj(
        last,
        nonce,
        time,
        validations,
        merkle,
        publisher
    )

    if not (
        #Calculate the hash.
        (result.setHash(SHA512(result.serialize()))) and
        #Set the proof.
        (result.setProof(proof)) and
        #Calculate the Argon hash.
        (result.setArgon(Argon(result.getHash(), result.getProof().toString(16))))
    ):
        raise newException(ResultError, "Couldn't set the hash/proof/argon..")

    if not (
        #Set the miners.
        result.setMiners(miners) and
        #Calculate the miners hash.
        result.setMinersHash(SHA512(miners.serialize(nonce)))
    ):
        raise newException(ResultError, "Couldn't set the miners/miners hash..")

    #Verify the signature.
    if not newPublicKey(publisher).verify(result.getMinersHash(), signature):
        raise newException(ValueError, "Invalid miners' signature.")
    #Set the signature.
    if not result.setSignature(signature):
        raise newException(ResultError, "Couldn't set the signature.")
