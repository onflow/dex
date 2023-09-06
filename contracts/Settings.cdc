import LPToken from "LiquidityProviderToken"
import FungibleToken from "FungibleToken"

/**

Settings manages the DEX fees.

 */
pub contract Settings {

    // Event that is emitted when the contract is created
    pub event ContractInitialized()

    /// The fraction of the swap input to collect as the total trading fee
    access(contract) var poolTotalFee: UFix64
    /// The fraction of the swap input to collect as protocol fee (part of `poolTotalFee`)
    access(contract) var poolProtocolFee: UFix64
    /// The address to receive LP tokens as protocol fee
    pub var protocolFeeRecipient: Address

    /// Used in Pair to calculate total fee
    pub fun getPoolTotalFeeCoefficient(): UFix64 {
        return self.poolTotalFee * 1_000.0
    }

    /// Used in Pair to calculate protocol fee
    pub fun getPoolProtocolFeeCoefficient(): UFix64 {
        return self.poolTotalFee / self.poolProtocolFee - 1.0
    }

    /// Used in Pair to check if fee deposit should take place
    pub fun isFeeOn(): Bool {
        return self.poolProtocolFee > 0.0
    }

    /// Used in Pair to deposit minted LP tokens as protocol fee
    pub fun depositProtocolFee(vault: @MultiFungibleToken.Vault) {
        let feeCollectionRef = getAccount(self.protocolFeeRecipient)
            .getCapability<&LPToken.Collection{MultiFungibleToken.Receiver}>(LPToken.CollectionPublicPath)
            .borrow() ?? panic("Settings: Protocol fee receiver not found")
        feeCollectionRef.deposit(from: <-vault)
    }

    init() {
        self.poolTotalFee = 0.003 // The initial total fee is 0.3%
        self.poolProtocolFee = 0.0005 // The initial protocol fee is 0.05%
        self.protocolFeeRecipient = self.account.address // The default recipient is current account

        // LP token collection setup
        self.account.save(<-LPToken.createEmptyCollection(), to: LPToken.CollectionStoragePath)
        self.account.link<&LPToken.Collection{MultiFungibleToken.Receiver, MultiFungibleToken.CollectionPublic}>(
            LPToken.CollectionPublicPath,
            target: LPToken.CollectionStoragePath
        )

        emit ContractInitialized()
    }
}