#State Revert Test.

#Fuzzing lib.
import ../../../Fuzzed

#Util lib.
import ../../../../src/lib/Util

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Element libs.
import ../../../../src/Database/Consensus/Elements/Elements

#Difficulty, Block, Blockchain, and State libs.
import ../../../../src/Database/Merit/Difficulty
import ../../../../src/Database/Merit/Block
import ../../../../src/Database/Merit/Blockchain
import ../../../../src/Database/Merit/State

#Elements Testing lib.
import ../../Consensus/Elements/TestElements

#Merit Testing lib.
import ../TestMerit

#Compare Merit lib.
import ../CompareMerit

#Random standard lib.
import random

suite "Revert":
    setup:
        var
            #Database.
            db: DB = newTestDatabase()
            #Blockchain.
            blockchain: Blockchain = newBlockchain(
                db,
                "STATE_TEST",
                1,
                uint64(1)
            )
            #State.
            states: seq[State] = @[]

            #Miners.
            miners: seq[MinerWallet] = @[]
            #Miners we can remove Merit from.
            removable: seq[MinerWallet]
            #Selected miner to remove Merit from/for the next Block.
            miner: int

            #Elements we're adding to the Block.
            elements: seq[BlockElement]
            #Block we're mining.
            mining: Block

        #Create the initial state.
        states.add(
            newState(
                db,
                7,
                blockchain
            )
        )

        #Iterate over 20 'rounds'.
        for _ in 1 .. 20:
            #Remove Merit from a random amount of Merit Holders every few Blocks.
            if rand(3) == 0:
                removable = miners
                for _ in 0 .. min(rand(2), high(miners)):
                    miner = rand(high(removable))
                    elements.add(
                        newRandomMeritRemoval(
                            states[^1].reverseLookup(removable[miner].publicKey)
                        )
                    )
                    removable.del(miner)

            #Decide if this is a nickname or new miner Block.
            if (miners.len == 0) or (rand(2) == 0):
                #New miner.
                miner = miners.len
                miners.add(newMinerWallet())

                #Create the Block with the new miner.
                mining = newBlankBlock(
                    rx = blockchain.rx,
                    last = blockchain.tail.header.hash,
                    miner = miners[miner],
                    elements = elements
                )
            else:
                #Grab a random miner.
                miner = rand(high(miners))

                #Create the Block with the existing miner.
                mining = newBlankBlock(
                    rx = blockchain.rx,
                    last = blockchain.tail.header.hash,
                    nick = uint16(miner),
                    miner = miners[miner],
                    elements = elements
                )

            #Add it to the Blockchain and latest State.
            blockchain.processBlock(mining)
            discard states[^1].processBlock(blockchain)

            #Commit the DB.
            db.commit(blockchain.height)

            #Clear the Elements.
            elements = @[]

            #Copy the State.
            states.add(states[^1])

    noFuzzTest "Reversions.":
        var
            copy: State
            reloaded: State
        for s in 1 ..< states.len:
            var revertTo: int = rand(s - 1) + 1
            copy = states[s]
            copy.revert(blockchain, states[revertTo].processedBlocks)
            compare(copy, states[revertTo])

            reloaded = newState(db, 7, blockchain)
            compare(states[^1], reloaded)

        #Manually set the RandomX instance to null to make sure it's GC'able.
        blockchain.rx = nil

    lowFuzzTest "Chained reversions.":
        var
            copy: State
            reloaded: State
            revertedAtOnce: State

        copy = states[^(rand(3) + 1)]
        copy.revert(blockchain, copy.processedBlocks - (rand(3) + 1))
        copy.revert(blockchain, copy.processedBlocks - (rand(3) + 1))
        copy.revert(blockchain, copy.processedBlocks - (rand(3) + 1))

        revertedAtOnce = states[^1]
        revertedAtOnce.revert(blockchain, copy.processedBlocks)
        compare(copy, revertedAtOnce)

        reloaded = newState(db, 7, blockchain)
        compare(states[^1], reloaded)

        #Manually set the RandomX instance to null to make sure it's GC'able.
        blockchain.rx = nil
