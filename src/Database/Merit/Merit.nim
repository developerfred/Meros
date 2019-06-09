#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Consensus lib.
import ../Consensus/Consensus

#Merit DB lib.
import ../Filesystem/DB/MeritDB

#MeritHolderRecord object.
import ../common/objects/MeritHolderRecordObj
export MeritHolderRecordObj

#Miners object.
import objects/MinersObj
export MinersObj

#Every Merit lib.
import Difficulty
import BlockHeader
import Block
import Blockchain
import State
import Epochs

export Difficulty
export BlockHeader
export Block
export Blockchain
export State
export Epochs

#Merit master object for a blockchain and state.
type Merit* = ref object
    blockchain*: Blockchain
    state*: State
    epochs: Epochs

#Constructor.
proc newMerit*(
    db: DB,
    consensus: Consensus,
    genesis: string,
    blockTime: Natural,
    startDifficultyArg: string,
    live: Natural
): Merit {.forceCheck: [].} =
    #Extract the Difficulty.
    var startDifficulty: Hash[384]
    try:
        startDifficulty = startDifficultyArg.toHash(384)
    except ValueError as e:
        doAssert(false, "Invalid chain specs (start difficulty) passed to newMerit: " & e.msg)

    #Create the Merit object.
    result = Merit(
        blockchain: newBlockchain(
            db,
            genesis,
            blockTime,
            startDifficulty
        )
    )
    result.state = newState(db, live, result.blockchain.height)
    result.epochs = newEpochs(db, consensus, result.blockchain)

#Add a block.
proc processBlock*(
    merit: Merit,
    consensus: Consensus,
    newBlock: Block
): Epoch {.forceCheck: [
    ValueError,
    GapError,
    DataExists
].} =
    #Add the block to the Blockchain.
    try:
        merit.blockchain.processBlock(newBlock)
    except ValueError as e:
        fcRaise e
    except GapError as e:
        fcRaise e
    except DataExists as e:
        fcRaise e

    #Have the state process the block.
    merit.state.processBlock(merit.blockchain, newBlock)

    #Have the Epochs process the Block and return the popped Epoch.
    result = merit.epochs.shift(
        consensus,
        newBlock.records
    )
