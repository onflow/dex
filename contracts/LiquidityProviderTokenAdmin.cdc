import FungibleToken from "FungibleToken"


pub contract LiquidityProviderTokenAdmin {

    pub resource interface Administrator {

        pub fun mintTokens(amount: UFix64): @FungibleToken.Vault

        pub fun burnTokens(from: @FungibleToken.Vault)
    }

}