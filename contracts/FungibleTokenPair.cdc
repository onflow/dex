
import FungibleToken from "FungibleToken"

pub contract interface FungibleTokenPair {

    pub resource interface FungibleTokenPool {
        /// The identifier created from the combination of the both token types and using unsafeRandom() function
        pub let poolId: UInt64
        /// Type of token A's vault (e.g., A.0x1654653399040a61.FlowToken.Vault)
        pub let tokenAType: Type
        /// Type of token B's vault (e.g., A.0x3c5959b568896393.FUSD.Vault)
        pub let tokenBType: Type

        /// Burns the given LP tokens to withdraw its share of the pool.
        ///
        /// @param lpTokenVault The LP tokens to burn
        /// @return The withdrawn share of the pool as [token A vault, token B vault]
        pub fun redeem(lpTokenVault: @FungibleToken.Vault): @[FungibleToken.Vault; 2] {
            pre {
                lpTokenVault.balance > 0.0: "Pair: Zero balance to burn"
            }
            post {
                result[0].isInstance(self.tokenAType): "Pair: Unexpected burn output"
                result[1].isInstance(self.tokenBType): "Pair: Unexpected burn output"
            }
        }

        /// Mints new LP tokens by providing liquidity to the pool.
        ///
        /// @param vaultA Liquidity to provide for token A
        /// @param vaultB Liquidity to provide for token B
        /// @return New LP tokens as a share of the pool
        pub fun mint(vaultA: @FungibleToken.Vault, vaultB: @FungibleToken.Vault): @FungibleToken.Vault {
            pre {
                vaultA.balance > 0.0 && vaultB.balance > 0.0: "Pair: Zero mint input amount"
                vaultA.isInstance(self.tokenAType): "Pair: Invalid token A for mint"
                vaultB.isInstance(self.tokenBType): "Pair: Invalid token B for mint"
            }
        }

        /// Takes in a vault of token A or token B, then returns a vault of the other token
        /// with its balance equals to `forAmount`. It throws an error if the `xy = k` curve
        /// cannot be maintained.
        ///
        /// @param fromVault The input vault of the swap (either token A or token B)
        /// @param forAmount The expected output balance of the swap
        /// @return A vault of the other token in the pool with its balance equals to `forAmount`
        pub fun swap(fromVault: @FungibleToken.Vault, forAmount: UFix64): @FungibleToken.Vault {
            pre {
                forAmount > 0.0: "Pair: Zero swap output amount"
                fromVault.balance > 0.0: "Pair: Zero swap input amount"
                fromVault.isInstance(self.tokenAType) || fromVault.isInstance(self.tokenBType): "Pair: Invalid swap input type"
            }
            post {
                !result.isInstance(before(fromVault.getType())): "Pair: Unexpected swap output"
                result.isInstance(self.tokenAType) || result.isInstance(self.tokenBType): "Pair: Unexpected swap output"
                result.balance == forAmount: "Pair: Inaccurate swap output amount"
            }
        }

        /// returns [token A reserve, token B reserve]
        pub fun getReserves(): [UFix64; 2]
    }

}