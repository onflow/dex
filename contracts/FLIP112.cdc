import "FungibleToken"

pub contract interface FLIP112 {


   /// Below event get emitted during `swapExactSourceToTargetTokenUsingPath` & `swapExactSourceToTargetTokenUsingPathAndReturn`
   /// function call.
   ///
   /// @param senderAddress:    Address who initiated the swap. // TODO: It is not possible to know as per the proposed interface.
   /// @param receiverAddress:  Address who receives target token, It is optional because in case of 
   /// `swapExactSourceToTargetTokenUsingPathAndReturn` function target token vault would be returned instead of movement of funds in
   ///  receiver capability.
   /// @param sourceTokenAmount: Amount of sourceToken sender wants to swap.
   /// @param receivedTargetTokenAmount: Amount of targetToken receiver would receive after swapping given `sourceTokenAmount`.
   /// @param sourceToken: Type of sourceToken. eg. Type<FLOW>
   /// @param targetToken: Type of targetToken. eg. Type<USDC>
   pub event Swap(
        senderAddress: Address,
        receiverAddress: Address?,
        sourceTokenAmount: UFix64,
        receivedTargetTokenAmount: UFix64,
        sourceToken: Type,
        targetToken: Type
    )


    /// Resource that get returned after the `swapExactSourceToTargetTokenUsingPathAndReturn` function execution.
    pub resource interface ExactSwapAndReturnValue {
        /// It represents the Vault that holds target token and would be returned
        /// after a swap. 
        pub let targetTokenVault: @FungibleToken.Vault
        /// It is an optional vault that holds the leftover source tokens after a swap.
        pub let remainingSourceTokenVault: @FungibleToken.Vault?
    }

    pub resource interface ImmediateSwap {

        /// @notice It will Swap the source token for the target token
        ///
        /// If the user wants to swap USDC to FLOW then the
        /// sourceToTargetTokenPath is [Type<USDC>, Type<FLOW>] and
        /// USDC would be the source token
        ///
        /// Necessary constraints
        /// - For the given source vault balance, Swapped target token amount should be
        ///   greater than or equal to `exactTargetAmount`, otherwise swap would fail.
        /// - If the swap settlement time i.e getCurrentBlock().timestamp is less than or
        ///   equal to the provided expiry then the swap would fail.
        /// - Provided `recipient` capability should be valid otherwise the swap would fail.
        /// - If the provided path doesn’t exists then the swap would fail.
        ///
        /// @param sourceToTargetTokenPath: Off-chain computed path for reaching source token to target token
        ///                                 `sourceToTargetTokenPath[0]` should be the source token type while
        ///                                 `sourceToTargetTokenPath[sourceToTargetTokenPath.length - 1]` should be the target token
        ///                                 and all the remaining intermediaries token types would be necessary swap hops to swap the
        ///                                 source token with target token.
        /// @param sourceVault:             Vault that holds the source token.
        /// @param exactTargetAmount:       Exact amount expected from the swap, If swapped amount is less than `exactTargetAmount` then
        ///                                 function execution would throw a error.
        /// @param expiry:                  Unix timestamp after which trade would get invalidated.
        /// @param recipient:               A valid capability that receives target token after the completion of function execution.
        /// @param remainingSourceTokenRecipient: A valid capability that receives surplus source token after the completion of function execution.
        pub fun swapExactSourceToTargetTokenUsingPath(
            sourceToTargetTokenPath: Type[],
            sourceVault: @FungibleToken.Vault,
            exactTargetAmount: UFix64,
            expiry: UFix64,
            recipient: Capability<&{FungibleToken.Receiver}>,
            remainingSourceTokenRecipient: Capability<&{FungibleToken.Receiver}>
        )


        /// @notice It will Swap the source token for to target token and          
        /// return `ExactSwapAndReturnValue`
        ///
        /// If the user wants to swap USDC to FLOW then the
        /// sourceToTargetTokenPath is [Type<USDC>, Type<FLOW>] and
        /// USDC would be the source token.
        /// 
        /// This function would be more useful when smart contract is the function call initiator
        /// and wants to perform some actions using the receiving amount.
        ///
        /// Necessary constraints
        /// - For the given source vault balance, Swapped target token amount should be
        ///   greater than or equal to exactTargetAmount, otherwise swap would fail
        /// - If the swap settlement time i.e getCurrentBlock().timestamp is less than or equal to the provided expiry then the swap would fail
        /// - If the provided path doesn’t exists then the swap would fail.
        ///
        /// @param sourceToTargetTokenPath: Off-chain computed path for reaching source token to target token
        ///                                 `sourceToTargetTokenPath[0]` should be the source token type while
        ///                                 `sourceToTargetTokenPath[sourceToTargetTokenPath.length - 1]` should be the target token
        ///                                 and all the remaining intermediaries token types would be necessary swap hops to swap the
        ///                                 source token with target token.
        /// @param sourceVault:             Vault that holds the source token.
        /// @param exactTargetAmount:       Exact amount expected from the swap, If swapped amount is less than `exactTargetAmount` then
        ///                                 function execution would throw a error.
        /// @param expiry:                  Unix timestamp after which trade would get invalidated.
        /// @return A valid vault that holds target token and an optional vault that may hold leftover source tokens.
        pub fun swapExactSourceToTargetTokenUsingPathAndReturn(
            sourceToTargetTokenPath: Type[],
            sourceVault: @FungibleToken.Vault,
            exactTargetAmount: UFix64,
            expiry: UInt64
        ): ExactSwapAndReturnValue

    }


    pub resource interface ImmediateSwapQuotation {
        
        /// @notice Provides the quotation of the target token amount for the
        /// corresponding provided sell amount i.e amount of source tokens.
        ///
        /// If the source to target token path doesn't exists then below function
        /// would return `nil`.
        /// Below function would return the quoted amount after deduction of the fees.
        ///
        /// If the sourceToTargetTokenPath is [Type<FLOW>, Type<BLOCTO>]. 
        /// Where sourceToTargetTokenPath[0] is the source token while 
        /// sourceToTargetTokenPath[sourceToTargetTokenPath.length -1] is 
        /// target token. i.e. FLOW and BLOCTO respectively.
        ///
        /// @param sourceToTargetTokenPath: Offchain computed optimal path from
        ///                                 source token to target token.
        /// @param sourceAmount Amount of source token user wants to sell to buy target token.
        /// @return Amount of target token user would get after selling `sourceAmount`.
        ///
        pub fun getExactSellQuoteUsingPath(
            sourceToTargetTokenPath: Type[],
            sourceAmount: UFix64
        ): UFix64?


        /// @notice Provides the quotation of the source token amount if user wants to
        /// buy provided targetAmount, i.e. amount of target token.
        ///
        /// If the source to target token path doesn't exists then below function
        /// would return `nil`.
        /// Below function would return the quoted amount after deduction of the fees.
        ///
        /// If the sourceToTargetTokenPath is [Type<FLOW>, Type<BLOCTO>]. 
        /// Where sourceToTargetTokenPath[0] is the source token while 
        /// sourceToTargetTokenPath[sourceToTargetTokenPath.length -1] is 
        /// target token. i.e. FLOW and BLOCTO respectively.
        ///
        /// @param sourceToTargetTokenPath: Offchain computed optimal path from
        ///                                 source token to target token.
        /// @param targetAmount: Amount of target token user wants to buy.
        /// @return Amount of source token user has to pay to buy provided `targetAmount` of target token.
        ///
        pub fun getExactBuyQuoteUsingPath(
            sourceToTargetTokenPath: Type[],
            targetAmount: UFix64
        ): UFix64?

    }
}