import FungibleToken from "FungibleToken"
import LiquidityProviderToken from "LiquidityProviderToken"
import Math from "Math"
import MultiFungibleToken from "MultiFungibleToken.cdc"
import FungibleTokenPair from "FungibleTokenPair"
import Settings from "Settings.cdc"

/**
    Pair represents a token pair that can be swapped on the DEX.
*/

pub contract FungibleTokenPairExample {

    pub event Swap(poolId: UInt64, amountIn: UFix64, amountOut: UFix64, swapAForB: Bool)
    pub event Mint(poolId: UInt64, amountAIn: UFix64, amountBIn: UFix64)
    pub event Burn(poolId: UInt64, amountLP: UFix64, amountAOut: UFix64, amountBOut: UFix64)
    /// The initial liquidity that will be minted and locked
    /// by the pool in order to avoid division by zero. It's fixed to 1e-5.
    access(contract)  let MINIMUM_LIQUIDITY: UFix64
    access(self) let LiquidityProviderTokenAdmin: @LiquidityProviderToken.Admin

    pub resource Pool: FungibleTokenPair.FungibleTokenPool {
        pub let poolId: UInt64
        access(self) var kLast: UInt256

        pub let tokenAType: Type
        pub let tokenBType: Type

        access(self) var lastBlockTimestamp: UFix64
        // use Word64 instead of UFix64 because overflow is acceptable
        // as long as the delta can be computed correctly
        access(self) var lastPriceACumulative: Word64
        access(self) var lastPriceBCumulative: Word64

        access(self) let tokenAVault: @FungibleToken.Vault
        access(self) let tokenBVault: @FungibleToken.Vault
        access(self) let LiquidityProviderTokenMaster: @LiquidityProviderToken.TokenMaster

        pub fun burn(LiquidityProviderTokenVault: @MultiFungibleToken.Vault): @[FungibleToken.Vault; 2]  {
            pre {
                !self.lock: "Pair: Reentrant call"
            }
            post {
                !self.lock: "Pair: Lock not released"
            }
            self.lock = true

            let reserveALast = self.tokenAVault.balance
            let reserveBLast = self.tokenBVault.balance
            let liquidity = LiquidityProviderTokenVault.balance
            let balanceA = self.tokenAVault.balance
            let balanceB = self.tokenBVault.balance

            let isFeeOn = self.mintFee(reserveALast: reserveALast, reserveBLast: reserveBLast)

            // note that totalSupply can update in mintFee
            let totalSupply = Math.uFix64ToRawUInt256(LiquidityProviderToken.getTotalSupply(tokenId: self.poolId)!)
            let liquidityUInt256 = Math.uFix64ToRawUInt256(liquidity)

            // amountA = liquidity * balanceA / totalSupply
            let amountA = liquidityUInt256 * Math.uFix64ToRawUInt256(balanceA) / totalSupply
            // amountB = liquidity * balanceB / totalSupply
            let amountB = liquidityUInt256 * Math.uFix64ToRawUInt256(balanceB) / totalSupply

            assert(
                amountA > 0 && amountB > 0,
                message: "Pair: Insufficient liquidity to burn"
            )

            // burn LP tokens
            self.LiquidityProviderTokenMaster.burnTokens(vault: <-LiquidityProviderTokenVault)

            let outputTokens: @[FungibleToken.Vault; 2]  <-[
                <-self.tokenAVault.withdraw(amount: Math.rawUInt256ToUFix64(amountA)),
                <-self.tokenBVault.withdraw(amount: Math.rawUInt256ToUFix64(amountB))
            ]

            if isFeeOn {
                // kLast = balanceA * balanceB
                self.kLast = Math.uFix64ToRawUInt256(self.tokenAVault.balance)
                    * Math.uFix64ToRawUInt256(self.tokenBVault.balance)
            }

            self.updateCumulativePrices(reserveA: reserveALast, reserveB: reserveBLast)

            emit Burn(
                poolId: self.poolId,
                amountLP: liquidity,
                amountAOut: outputTokens[0].balance,
                amountBOut: outputTokens[1].balance
            )

            self.lock = false
            return <-outputTokens
        }

        pub fun mint(vaultA: @FungibleToken.Vault, vaultB: @FungibleToken.Vault): @LiquidityProviderToken.Vault {
            pre {
                !self.lock: "Pair: Reentrant call"
            }
            post {
                !self.lock: "Pair: Lock not released"
            }
            self.lock = true

            let reserveALast = self.tokenAVault.balance
            let reserveBLast = self.tokenBVault.balance

            let amountA = vaultA.balance
            let amountB = vaultB.balance

            self.tokenAVault.deposit(from: <-vaultA)
            self.tokenBVault.deposit(from: <-vaultB)

            let isFeeOn = self.mintFee(reserveALast: reserveALast, reserveBLast: reserveBLast)

            // note that totalSupply can update in mintFee
            let totalSupply = Math.uFix64ToRawUInt256(LiquidityProviderToken.getTotalSupply(tokenId: self.poolId)!)
            var liquidity = 0 as UInt256
            if totalSupply == 0 {
                // first liquidity for this pool
                // liquidity = sqrt(amountA * amountB) - MINIMUM_LIQUIDITY
                liquidity = Math.sqrt(Math.uFix64ToRawUInt256(amountA) * Math.uFix64ToRawUInt256(amountB))
                    - Math.uFix64ToRawUInt256(FungibleTokenPairExample.MINIMUM_LIQUIDITY)

                // permanently lock the first MINIMUM_LIQUIDITY tokens
                let minimumLP <- self.LiquidityProviderTokenMaster.mintTokens(amount: FungibleTokenPairExample.MINIMUM_LIQUIDITY)
                destroy minimumLP
            } else {
                // liquidityA = amountA * totalSupply / reserveALast
                let liquidityA = Math.uFix64ToRawUInt256(amountA) * totalSupply
                    / Math.uFix64ToRawUInt256(reserveALast)

                // liquidityB = amountB * totalSupply / reserveBLast
                let liquidityB = Math.uFix64ToRawUInt256(amountB) * totalSupply
                    / Math.uFix64ToRawUInt256(reserveBLast)

                // liquidity = min(liquidityA, liquidityB)
                liquidity = liquidityA > liquidityB ? liquidityB : liquidityA
            }

            assert(liquidity > 0, message: "Pair: Cannot mint zero liquidity")
            let LiquidityProviderTokenVault <-self.LiquidityProviderTokenMaster.mintTokens(amount: Math.rawUInt256ToUFix64(liquidity))

            if isFeeOn {
                // kLast = balanceA * balanceB
                self.kLast = Math.uFix64ToRawUInt256(self.tokenAVault.balance)
                    * Math.uFix64ToRawUInt256(self.tokenBVault.balance)
            }

            self.updateCumulativePrices(reserveA: reserveALast, reserveB: reserveBLast)

            emit Mint(poolId: self.poolId, amountAIn: amountA, amountBIn: amountB)

            self.lock = false
            return <-LiquidityProviderTokenVault
        }

        pub fun swap(fromVault: @FungibleToken.Vault, forAmount: UFix64): @FungibleToken.Vault {
            pre {
                !self.lock: "Pair: Reentrant call"
            }
            post {
                !self.lock: "Pair: Lock not released"
            }
            self.lock = true

            let reserveALast = self.tokenAVault.balance
            let reserveBLast = self.tokenBVault.balance

            let swapAForB = fromVault.isInstance(self.tokenAType)
            var amountAIn = 0.0
            var amountBIn = 0.0
            var outputVault: @FungibleToken.Vault? <- nil

            if swapAForB {
                assert(reserveBLast > forAmount, message: "Pair: Insufficient liquidity")
                amountAIn = fromVault.balance
                self.tokenAVault.deposit(from: <-fromVault)
                outputVault <-!self.tokenBVault.withdraw(amount: forAmount)
            } else {
                assert(reserveALast > forAmount, message: "Pair: Insufficient liquidity")
                amountBIn = fromVault.balance
                self.tokenBVault.deposit(from: <-fromVault)
                outputVault <-!self.tokenAVault.withdraw(amount: forAmount)
            }

            let totalFeeCoefficient = UInt256(Settings.getPoolTotalFeeCoefficient())

            // adjustedBalanceA = balanceA * 1000 - amountAIn * TotalFeeCoefficient
            let adjustedBalanceA = Math.uFix64ToRawUInt256(self.tokenAVault.balance) * 1000
                - Math.uFix64ToRawUInt256(amountAIn) * totalFeeCoefficient

            // adjustedBalanceB = balanceB * 1000 - amountBIn * TotalFeeCoefficient
            let adjustedBalanceB = Math.uFix64ToRawUInt256(self.tokenBVault.balance) * 1000
                - Math.uFix64ToRawUInt256(amountBIn) * totalFeeCoefficient

            // prevK = reserveALast * reserveBLast * 1000^2
            let prevK = Math.uFix64ToRawUInt256(reserveALast)
                * Math.uFix64ToRawUInt256(reserveBLast)
                * 1_000_000

            assert(
                adjustedBalanceA * adjustedBalanceB >= prevK,
                message: "Pair: K not maintained"
            )

            self.updateCumulativePrices(reserveA: reserveALast, reserveB: reserveBLast)

            emit Swap(
                poolId: self.poolId,
                amountIn: swapAForB ? amountAIn : amountBIn,
                amountOut: forAmount,
                swapAForB: swapAForB
            )

            self.lock = false
            return <-outputVault!
        }

        pub fun getReserves(): [UFix64; 2] {
            return [self.tokenAVault.balance, self.tokenBVault.balance]
        }

        /// Mints new LP tokens as protocol fees.
        access(self) fun mintFee(reserveALast: UFix64, reserveBLast: UFix64): Bool {
            let isFeeOn = Settings.isFeeOn()
            if isFeeOn {
                if (self.kLast > 0) {
                    // rootK = sqrt(reserveALast * reserveBLast)
                    let rootK = Math.sqrt(Math.uFix64ToRawUInt256(reserveALast)
                        * Math.uFix64ToRawUInt256(reserveBLast))

                    // rootKLast = sqrt(kLast)
                    let rootKLast = Math.sqrt(self.kLast)

                    let totalSupply = Math.uFix64ToRawUInt256(LiquidityProviderToken.getTotalSupply(tokenId: self.poolId)!)
                    if (rootK > rootKLast) {
                        // numerator = totalSupply * (rootK - rootKLast)
                        let numerator = totalSupply * (rootK - rootKLast)

                        // denominator = rootK * ProtocolFeeCoefficient + rootKLast
                        let denominator = rootK * UInt256(Settings.getPoolProtocolFeeCoefficient()) + rootKLast

                        // liquidity = numerator / denominator
                        let liquidity = Math.rawUInt256ToUFix64(numerator / denominator)
                        if (liquidity > 0.0) {
                            let protocolFee <-self.LiquidityProviderTokenMaster.mintTokens(amount: liquidity)
                            Settings.depositProtocolFee(vault: <-protocolFee)
                        }
                    }
                }
            } else if (self.kLast > 0) {
                self.kLast = 0
            }

            return isFeeOn
        }

        /// Updates the cumulative price information if this function
        /// is called for the first time in the current block.
        access(self) fun updateCumulativePrices(reserveA: UFix64, reserveB: UFix64) {
            let curTimestamp = getCurrentBlock().timestamp
            let timeElapsed = curTimestamp - self.lastBlockTimestamp

            if timeElapsed > 0.0 && reserveA != 0.0 && reserveB != 0.0 {
                self.lastBlockTimestamp = curTimestamp
                self.lastPriceACumulative = Math.computePriceCumulative(
                    lastPrice1Cumulative: self.lastPriceACumulative,
                    reserve1: reserveA,
                    reserve2: reserveB,
                    timeElapsed: timeElapsed
                )
                self.lastPriceBCumulative = Math.computePriceCumulative(
                    lastPrice1Cumulative: self.lastPriceBCumulative,
                    reserve1: reserveB,
                    reserve2: reserveA,
                    timeElapsed: timeElapsed
                )
            }
        }

        init(
            vaultA: @FungibleToken.Vault,
            vaultB: @FungibleToken.Vault,
            LiquidityProviderTokenMaster: @LiquidityProviderToken.TokenMaster,
            poolId: UInt64
        ) {
            pre {
                vaultA.balance == 0.0: "Pair: Pool creation requires empty vaults"
                vaultB.balance == 0.0: "Pair: Pool creation requires empty vaults"
                !vaultA.isInstance(vaultB.getType()) && !vaultB.isInstance(vaultA.getType()):
                    "Pair: Pool creation requires vaults of different types"
            }
            self.poolId = poolId
            self.kLast = 0

            self.tokenAVault <- vaultA
            self.tokenBVault <- vaultB
            self.tokenAType = self.tokenAVault.getType()
            self.tokenBType = self.tokenBVault.getType()

            self.lastBlockTimestamp = getCurrentBlock().timestamp
            self.lastPriceACumulative = 0
            self.lastPriceBCumulative = 0

            self.LiquidityProviderTokenMaster <- LiquidityProviderTokenMaster

            self.lock = false
        }

        destroy() {
            destroy self.tokenAVault
            destroy self.tokenBVault
            destroy self.LiquidityProviderTokenMaster
        }
    }

    /// Creates a new pool resource.
    /// This function is not harmful to access directly but it is recommended
    /// to be used from the `Factory` contract so it can keep track of all pools
    /// deployed. 
    access(account) fun createPool(
        vaultA: @FungibleToken.Vault,
        vaultB: @FungibleToken.Vault,
        poolId: UInt64,
        admin: @AnyResource{LiquidityProviderToken.IAdministrator}
    ): @Pool {
        // Create a new instance of the LiquidityProviderToken.
        LiquidityProviderToken(pairId: poolId.toString())
        return <-create FungibleTokenPairExample.Pool(
            vaultA: <-vaultA,
            vaultB: <-vaultB,
            LiquidityProviderTokenMaster: <-admin,
            poolId: poolId
        )
    }

    init() {
        self.MINIMUM_LIQUIDITY = 0.00001
    }
}