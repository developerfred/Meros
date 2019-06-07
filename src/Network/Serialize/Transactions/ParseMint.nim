#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Mint object.
import ../../../Database/Transactions/objects/MintObj

#Common serialization functions.
import ../SerializeCommon

#Parse function.
proc parseMint*(
    mintStr: string
): Mint {.forceCheck: [
    ValueError,
    BLSError
].} =
    #Nonce | Recepient | Meros
    var mintSeq: seq[string] = mintStr.deserialize(
        INT_LEN,
        BLS_PUBLIC_KEY_LEN,
        MEROS_LEN
    )

    if mintSeq[1].len < 48:
        raise newException(ValueError, "parseMint not handed enough data to get the mint.")

    #Create the Mint.
    try:
        result = newMintObj(
            mintSeq[0].fromBinary(),
            newBLSPublicKey(mintSeq[1]),
            uint64(mintSeq[2].fromBinary())
        )
    except BLSError as e:
        raise e

    #Hash it.
    try:
        result.hash = Blake384("\0" & mintSeq.reserialize(0, 2))
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a Mint: " & e.msg)
