import FungibleToken from "FungibleToken"
import MetadataViews from "MetadataViews"
import FungibleTokenMetadataViews from "FungibleTokenMetadataViews"
import LiquidityProviderTokenView from "LiquidityProviderTokenView"
import LiquidityProviderTokenAdmin from "LiquidityProviderTokenAdmin"

pub contract LiquidityProviderToken: FungibleToken {

    /// Total supply of LiquidityProviderTokens in existence
    pub var totalSupply: UFix64

    /// Storage and Public Paths
    pub let VaultStoragePath: StoragePath
    pub let VaultPublicPath: PublicPath
    pub let ReceiverPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath

    pub let pairId: String

     /// The event that is emitted when the contract is created
    pub event TokensInitialized(initialSupply: UFix64)

    /// The event that is emitted when tokens are withdrawn from a Vault
    pub event TokensWithdrawn(amount: UFix64, from: Address?)

    /// The event that is emitted when tokens are deposited to a Vault
    pub event TokensDeposited(amount: UFix64, to: Address?)

    /// The event that is emitted when new tokens are minted
    pub event TokensMinted(amount: UFix64)

    /// The event that is emitted when tokens are destroyed
    pub event TokensBurned(amount: UFix64)

    /// The event that is emitted when a new minter resource is created
    pub event MinterCreated(allowedAmount: UFix64)

    /// The event that is emitted when a new burner resource is created
    pub event BurnerCreated()

    /// Each user stores an instance of only the Vault in their storage
    /// The functions in the Vault and governed by the pre and post conditions
    /// in FungibleToken when they are called.
    /// The checks happen at runtime whenever a function is called.
    ///
    /// Resources can only be created in the context of the contract that they
    /// are defined in, so there is no way for a malicious user to create Vaults
    /// out of thin air. A special Minter resource needs to be defined to mint
    /// new tokens.
    ///
    pub resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance, MetadataViews.Resolver {

        /// The total balance of this vault
        pub var balance: UFix64

        /// Initialize the balance at resource creation time
        init(balance: UFix64) {
            self.balance = balance
        }

        /// Function that takes an amount as an argument
        /// and withdraws that amount from the Vault.
        /// It creates a new temporary Vault that is used to hold
        /// the money that is being transferred. It returns the newly
        /// created Vault to the context that called so it can be deposited
        /// elsewhere.
        ///
        /// @param amount: The amount of tokens to be withdrawn from the vault
        /// @return The Vault resource containing the withdrawn funds
        ///
        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }

        /// Function that takes a Vault object as an argument and adds
        /// its balance to the balance of the owners Vault.
        /// It is allowed to destroy the sent Vault because the Vault
        /// was a temporary holder of the tokens. The Vault's balance has
        /// been consumed and therefore can be destroyed.
        ///
        /// @param from: The Vault resource containing the funds that will be deposited
        ///
        pub fun deposit(from: @FungibleToken.Vault) {
            let vault <- from as! @LiquidityProviderToken.Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }

        destroy() {
            if self.balance > 0.0 {
                LiquidityProviderToken.totalSupply = LiquidityProviderToken.totalSupply - self.balance
            }
        }

        /// The way of getting all the Metadata Views implemented by LiquidityProviderToken
        ///
        /// @return An array of Types defining the implemented views. This value will be used by
        ///         developers to know which parameter to pass to the resolveView() method.
        ///
        pub fun getViews(): [Type] {
            return [
                Type<FungibleTokenMetadataViews.FTView>(),
                Type<FungibleTokenMetadataViews.FTDisplay>(),
                Type<FungibleTokenMetadataViews.FTVaultData>(),
                Type<LiquidityProviderTokenView.LPTokenData>()
            ]
        }

        /// The way of getting a Metadata View out of the LiquidityProviderToken
        ///
        /// @param view: The Type of the desired view.
        /// @return A structure representing the requested view.
        ///
        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<FungibleTokenMetadataViews.FTView>():
                    return FungibleTokenMetadataViews.FTView(
                        ftDisplay: self.resolveView(Type<FungibleTokenMetadataViews.FTDisplay>()) as! FungibleTokenMetadataViews.FTDisplay?,
                        ftVaultData: self.resolveView(Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
                    )
                case Type<FungibleTokenMetadataViews.FTDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "url"
                        ),
                        mediaType: "image/svg+xml"
                    )
                    let medias = MetadataViews.Medias([media])
                    return FungibleTokenMetadataViews.FTDisplay(
                        name: "Liquidity Fungible Token",
                        symbol: "LPFT-".concat(LiquidityProviderToken.pairId),
                        description: "This fungible token is used as an example to help you develop your next FT #onFlow.",
                        externalURL: MetadataViews.ExternalURL("https://example-ft.onflow.org"),
                        logos: medias,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/flow_blockchain")
                        }
                    )
                case Type<FungibleTokenMetadataViews.FTVaultData>():
                    return FungibleTokenMetadataViews.FTVaultData(
                        storagePath: LiquidityProviderToken.VaultStoragePath,
                        receiverPath: LiquidityProviderToken.ReceiverPublicPath,
                        metadataPath: LiquidityProviderToken.VaultPublicPath,
                        providerPath: /private/LiquidityProviderTokenVault,
                        receiverLinkedType: Type<&LiquidityProviderToken.Vault{FungibleToken.Receiver}>(),
                        metadataLinkedType: Type<&LiquidityProviderToken.Vault{FungibleToken.Balance, MetadataViews.Resolver}>(),
                        providerLinkedType: Type<&LiquidityProviderToken.Vault{FungibleToken.Provider}>(),
                        createEmptyVaultFunction: (fun (): @LiquidityProviderToken.Vault {
                            return <-LiquidityProviderToken.createEmptyVault()
                        })
                    )
                case Type<LiquidityProviderTokenView.LPTokenData>():
                    return LiquidityProviderTokenView.LPTokenData(pairId: LiquidityProviderToken.pairId)
            }
            return nil
        }
    }

    /// Function that creates a new Vault with a balance of zero
    /// and returns it to the calling context. A user must call this function
    /// and store the returned Vault in their storage in order to allow their
    /// account to be able to receive deposits of this token type.
    ///
    /// @return The new Vault resource
    ///
    pub fun createEmptyVault(): @Vault {
        return <-create Vault(balance: 0.0)
    }


    /// Resource object that token admin accounts can hold to mint/burn new tokens.
    ///
    pub resource Administrator: LiquidityProviderTokenAdmin.Administrator {

        /// Function that mints new tokens, adds them to the total supply,
        /// and returns them to the calling context.
        ///
        /// @param amount: The quantity of tokens to mint
        /// @return The Vault resource containing the minted tokens
        ///
        pub fun mintTokens(amount: UFix64): @FungibleToken.Vault {
            pre {
                amount > 0.0: "Amount minted must be greater than zero"
            }
            LiquidityProviderToken.totalSupply = LiquidityProviderToken.totalSupply + amount
            emit TokensMinted(amount: amount)
            return <-create Vault(balance: amount) as! @FungibleToken.Vault
        }

        /// Function that destroys a Vault instance, effectively burning the tokens.
        ///
        /// Note: the burned tokens are automatically subtracted from the
        /// total supply in the Vault destructor.
        ///
        /// @param from: The Vault resource containing the tokens to burn
        ///
        pub fun burnTokens(from: @FungibleToken.Vault) {
            let vault <- from as! @LiquidityProviderToken.Vault
            let amount = vault.balance
            destroy vault
            emit TokensBurned(amount: amount)
        }

        init() {}
    }

    init(pairId: UInt64)
    {
        self.totalSupply = 0.0
        self.pairId = pairId
        self.VaultStoragePath = StoragePath(identifier: pairId.concat("-").concat("LiquidityProviderTokenVault"))!
        self.VaultPublicPath = PublicPath(identifier: pairId.concat("-").concat("LiquidityProviderTokenMetadata"))!
        self.ReceiverPublicPath = PublicPath(identifier: pairId.concat("-").concat("LiquidityProviderTokenReceiver"))!
        self.AdminStoragePath = StoragePath(identifier: pairId.concat("-").concat("LiquidityProviderTokenAdmin"))!
        self.account.save(<- create Administrator(), to: /storage/LiquidityProviderTokenAdminstrator)
        emit TokensInitialized(initialSupply: 0.0)
    }
}