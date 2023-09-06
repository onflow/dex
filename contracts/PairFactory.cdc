import FlowStorageFees from 0xf8d6e0586b0a20c7
import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from "FungibleToken"
import Math from "Math"
import FungibleTokenPair from "FungibleTokenPair"
import FungibleTokenPairExample from "FungibleTokenPairExample"


/// Factory is responsible for creating new pools and querying existing pools.
pub contract PairFactory {

    access(contract) let FlowTokenReceiverPath: PublicPath
    access(contract) let PoolStoragePath: StoragePath
    pub let PoolPublicPath: PublicPath

    /// A mapping from pair hash to pool id (pool owner's address in UInt64)
    access(contract) let pairHashToPoolId: {String: UInt64}
    /// A mapping to keep track of the address of the pool corresponding to the poolId
    access(contract) let poolIdToPoolAddress: {UInt64: Address}
    /// An array of pool ids (pool owner's addresses in UInt64) in their creation order
    access(self) let pools: [UInt64]

    /// Fees to store the LiquidityProviderToken contract and its operation
    pub let OPERATIONAL_FEES: UFix64

    // Event that is emitted when the contract is created
    pub event ContractInitialized()

    /// Creates a new liquidity pool resource for the given token pair,
    /// and stores the new resource in a new account.
    ///
    /// @param vaultA An empty vault of token A in the pair
    /// @param vaultB An empty vault of token B in the pair
    /// @param fees A vault that contains the minimum amount of Flow token for account creation
    /// @return The pool id of the new liquidity pool
    pub fun createPoolForPair(
        vaultA: @FungibleToken.Vault,
        vaultB: @FungibleToken.Vault,
        fees: @FungibleToken.Vault
    ): UInt64 {
        pre {
            vaultA.balance == 0.0: "Pool creation requires empty vaults"
            vaultB.balance == 0.0: "Pool creation requires empty vaults"
            fees.balance >= FlowStorageFees.minimumStorageReservation + OPERATIONAL_FEES :
                "Expecting minimum storage fees for account creation"
        }

        // deposits fees for account creation
        let receiverRef = self.account
            .getCapability(self.FlowTokenReceiverPath)
            .borrow<&FlowToken.Vault{FungibleToken.Receiver}>()
            ?? panic("Could not borrow receiver reference to the Flow Token Vault")
        receiverRef.deposit(from: <- fees)

        // computes the hash strings for both (A, B) and (B, A)
        let tokenATypeIdentifier = vaultA.getType().identifier
        let tokenBTypeIdentifier = vaultB.getType().identifier
        let pairABHash = self.getPairHash(
            tokenATypeIdentifier: tokenATypeIdentifier,
            tokenBTypeIdentifier: tokenBTypeIdentifier
        )
        let pairBAHash = self.getPairHash(
            tokenATypeIdentifier: tokenBTypeIdentifier,
            tokenBTypeIdentifier: tokenATypeIdentifier
        )

        assert(
            !self.pairHashToPoolId.containsKey(pairABHash) && !self.pairHashToPoolId.containsKey(pairBAHash),
            message: "Pool already exists for this pair"
        )

        // creates a new account without an owner (public key)
        let newAccount = AuthAccount(payer: self.account)

        // converts the new account's address to pool id
        let newPoolId = Math.addressToUInt64(address: newAccount.address)

        // creates the new liquidity pool resource
        let newPool <- FungibleTokenPairExample.createPool(vaultA: <-vaultA, vaultB: <-vaultB, poolId: newPoolId, poolAccount: newAccount)

        // stores the new pool into the new account
        newAccount.save(<-newPool, to: self.PoolStoragePath)
        newAccount.link<&FungibleTokenPairExample.Pool{FungibleTokenPair.FungibleTokenPool}>(self.PoolPublicPath, target: self.PoolStoragePath)
        // registers the pairs (A, B) and (B, A), assigns them to the same pool
        self.pairHashToPoolId[pairABHash] = newPoolId
        self.pairHashToPoolId[pairBAHash] = newPoolId
        // register the poolAddress corresponds to poolId
        self.poolIdToPoolAddress[newPoolId] = newAccount.address
        // also appends the new pool id to `self.pools`
        self.pools.append(newPoolId)

        return newPoolId
    }

    // Queries a liquidity pool resource reference using the types
    // of a token pair.
    //
    // @param tokenAType The type of token A's vault
    // @param tokenBType The type of token B's vault
    // @return The resource reference of the requested liquidity pool, or nil
    //  if there's no liquidity pool for the token pair
    pub fun getPoolByTypes(tokenAType: Type, tokenBType: Type): &FungibleTokenPairExample.Pool{FungibleTokenPair.FungibleTokenPool}? {
        let pairHash = self.getPairHash(
            tokenATypeIdentifier: tokenAType.identifier,
            tokenBTypeIdentifier: tokenBType.identifier
        )

        if let poolId = self.pairHashToPoolId[pairHash] {
            return self.getPoolById(poolId: poolId)
        }
        return nil
    }

    /// Queries a liquidity pool resource reference using the type
    /// identifiers of a token pair.
    //
    /// @param tokenATypeIdentifier The type identifier of token A's vault
    /// @param tokenBTypeIdentifier The type identifier of token B's vault
    /// @return The resource reference of the requested liquidity pool, or nil
    ///  if there's no liquidity pool for the token pair
    pub fun getPoolByTypeIdentifiers(tokenATypeIdentifier: String, tokenBTypeIdentifier: String): &FungibleTokenPairExample.Pool{FungibleTokenPair.FungibleTokenPool}? {
        let pairHash = self.getPairHash(
            tokenATypeIdentifier: tokenATypeIdentifier,
            tokenBTypeIdentifier: tokenBTypeIdentifier
        )

        if let poolId = self.pairHashToPoolId[pairHash] {
            return self.getPoolById(poolId: poolId)
        }
        return nil
    }

    /// Computes the unique hash for a pair (token A, token B) indicated by
    /// the given type identifiers.
    ///
    /// @param tokenATypeIdentifier The type identifier of token A's vault (e.g., A.0x1654653399040a61.FlowToken.Vault)
    /// @param tokenBTypeIdentifier The type identifier of token B's vault (e.g., A.0x3c5959b568896393.FUSD.Vault)
    /// @return A unique hash string for the pair
    access(self) fun getPairHash(tokenATypeIdentifier: String, tokenBTypeIdentifier: String): String {
        // "\n" should be an invalid syntax for type identifier, thus making sure the raw id
        // is unique for each pair of type identifiers.
        let rawId = tokenATypeIdentifier.concat("\n").concat(tokenBTypeIdentifier)
        return String.encodeHex(HashAlgorithm.SHA3_256.hash(rawId.utf8))
    }

    /// Queries a liquidity pool resource reference by borrowing it from
    /// the address represented by the pool id.
    ///
    /// @param poolId The pool id representing the pool owner's address
    /// @return The resource reference of the requested liquidity pool
    pub fun getPoolById(poolId: UInt64): &FungibleTokenPairExample.Pool{FungibleTokenPair.FungibleTokenPool} {
        let address = Address(poolId)
        return getAccount(address).getCapability<&FungibleTokenPairExample.Pool{FungibleTokenPair.FungibleTokenPool}>(self.PoolPublicPath).borrow()
            ?? panic("Couldn't borrow pool from the account")
    }

    init() {
        self.FlowTokenReceiverPath = /public/flowTokenReceiver
        self.PoolStoragePath = /storage/poolStoragePath
        self.PoolPublicPath = /public/poolPublicPath
        self.pairHashToPoolId = {}
        self.poolIdToPoolAddress = {}
        self.pools = []
        self.OPERATIONAL_FEES = 5.0 // 5 FLOW

        emit ContractInitialized()
    }
}