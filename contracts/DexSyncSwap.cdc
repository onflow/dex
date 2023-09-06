import FungibleToken from 0x9a0766d93b6608b7

pub contract DexSyncSwap {


   /// Below event get emitted during `swapExactSourceToTargetTokenUsingPath` & `swapExactSourceToTargetTokenUsingPathAndReturn`
   /// function call.
   ///
   /// @param receiverAddress:  Address who receives target token, It is optional because in case of 
   /// `swapExactSourceToTargetTokenUsingPathAndReturn` function target token vault would be returned instead of movement of funds in
   ///  receiver capability.
   /// @param sourceTokenAmount: Amount of sourceToken sender wants to swap.
   /// @param receivedTargetTokenAmount: Amount of targetToken receiver would receive after swapping given `sourceTokenAmount`.
   /// @param sourceToken: Type of sourceToken. eg. Type<FLOW>
   /// @param targetToken: Type of targetToken. eg. Type<USDC>
   pub event Swap(
        receiverAddress: Address?,
        sourceTokenAmount: UFix64,
        receivedTargetTokenAmount: UFix64,
        sourceToken: Type,
        targetToken: Type?
    )


    /// Resource that get returned after the `swapExactSourceToTargetTokenUsingPathAndReturn` function execution.
    pub resource interface ExactSwapAndReturnValue {
        /// It represents the Vault that holds target token and would be returned
        /// after a swap. 
        pub let targetTokenVault: @FungibleToken.Vault
        /// It is an optional vault that holds the leftover source tokens after a swap.
        pub let remainingSourceTokenVault: @FungibleToken.Vault?
        /// Below stores the `remainingSourceTokenVault!.balance` value, It is stored in the seperate variable
        /// instead of accessing it like this `remainingSourceTokenVault!.balance` because there is no utility function
        /// present to know whether the optional resource variable has value or nil.
        ///
        ///     ```
        ///     if remainingSourceTokenVault is optional
        ///         remainingSourceTokenVaultAmount = 0
        ///     else 
        ///         remainingSourceTokenVaultAmount = remainingSourceTokenVault.balance
        ///     ```
        ///
        pub let remainingSourceTokenVaultAmount: UFix64
    }

    pub resource interface ImmediateSwap {

        /// @notice It will Swap the source token for the target token, In the below API, provided `sourceVault` would be consumed fully
        ///
        /// If the user wants to swap USDC to FLOW then the
        /// sourceToTargetTokenPath is [Type<USDC>, Type<FLOW>] and
        /// USDC would be the source token
        ///
        /// Necessary constraints
        /// - For the given source vault balance, Swapped target token amount should be
        ///   greater than or equal to `minimumTargetTokenAmount`, otherwise swap would fail.
        /// - If the swap settlement time i.e getCurrentBlock().timestamp is less than or
        ///   equal to the provided expiry then the swap would fail.
        /// - Provided `recipient` capability should be valid otherwise the swap would fail.
        /// - If the provided path doesn’t exists then the swap would fail.
        ///
        /// @param sourceToTargetTokenPath:   Off-chain computed path for swapping source token to target token
        ///                                   `sourceToTargetTokenPath[0]` should be the source token type while
        ///                                   `sourceToTargetTokenPath[sourceToTargetTokenPath.length - 1]` should be the target token
        ///                                    and all the remaining intermediaries token types would be necessary swap hops to swap the
        ///                                    source token with target token.
        /// @param sourceVault:                Vault that holds the source token.
        /// @param minimumTargetTokenAmount:   Minimum amount expected from the swap, If swapped amount is less than `minimumTargetTokenAmount`
        ///                                    then function execution would throw a error.
        /// @param expiry:                     Unix timestamp after which trade would get invalidated.
        /// @param recipient:                  A valid capability that receives target token after the completion of function execution.
        /// @return receivedTargetTokenAmount: Amount of tokens the user would receive after the swap
        pub fun swapExactSourceToTargetTokenUsingPath(
            sourceToTargetTokenPath: [Type],
            sourceVault: @FungibleToken.Vault,
            minimumTargetTokenAmount: UFix64,
            expiry: UFix64,
            recipient: Capability<&{FungibleToken.Receiver}>,
        ): UFix64
        {
            pre {
                expiry >= getCurrentBlock().timestamp : "Expired swap request"
                recipient.check() : "Provided recipient capability can not be borrowed"
                sourceToTargetTokenPath.length >= 2 : "Incorrect source to target token path"
                sourceVault.balance > 0.0 : "Swap is not permitted for zero source vault balance"
            }
            post {
                result >= minimumTargetTokenAmount: "Minimum target token amount was not received during the swap"
                DexSyncSwap.emitSwapEvent(
                    receiverAddress: recipient.address,
                    sourceTokenAmount: before(sourceVault.balance),
                    receivedTargetTokenAmount: result,
                    sourceToken: before(sourceVault.getType()),
                    targetToken: recipient.borrow()!.getSupportedVaultTypes().keys.length == 1 ? recipient.borrow()!.getSupportedVaultTypes().keys[0] : nil
                )
            }
        }


        /// @notice This will swap the exact source token for the target token and          
        /// return `FungibleToken.Vault`
        ///
        /// If the user wants to swap USDC to FLOW then the
        /// sourceToTargetTokenPath is [Type<USDC>, Type<FLOW>] and
        /// USDC would be the source token.
        /// 
        /// This function would be more useful when a smart contract is the function call initiator
        /// and wants to perform some actions using the receiving amount.
        ///
        /// Necessary constraints
        /// - For the given source vault balance, Swapped target token amount should be
        ///   greater than or equal to `minimumTargetTokenAmount`, otherwise swap would fail
        /// - If the swap settlement time i.e getCurrentBlock().timestamp is less than or equal to the provided expiry then the swap would fail
        /// - If the provided path doesn’t exist then the swap would fail.
        ///
        /// @param sourceToTargetTokenPath:  Off-chain computed path for reaching source token to target token
        ///                                 `sourceToTargetTokenPath[0]` should be the source token type while
        ///                                 `sourceToTargetTokenPath[sourceToTargetTokenPath.length - 1]` should be the target token
        ///                                  and all the remaining intermediaries token types would be necessary swap hops to swap the
        ///                                  source token with target token.
        /// @param sourceVault:              Vault that holds the source token.
        /// @param minimumTargetTokenAmount: Minimum amount expected from the swap, If swapped amount is less than `minimumTargetTokenAmount`
        ///                                  then function execution would throw a error.
        /// @param expiry:                   Unix timestamp after which the trade would get invalidated.
        /// @return A valid vault that holds target token and an optional vault that may hold leftover source tokens.
        pub fun swapExactSourceToTargetTokenUsingPathAndReturn(
            sourceToTargetTokenPath: [Type],
            sourceVault: @FungibleToken.Vault,
            minimumTargetTokenAmount: UFix64,
            expiry: UFix64
        ): @FungibleToken.Vault {
            pre {
                expiry >= getCurrentBlock().timestamp : "Expired swap request"
                sourceToTargetTokenPath.length >= 2 : "Incorrect source to target token path"
                sourceVault.balance > 0.0 : "Swap is not permitted for zero source vault balance"
            }
            post {
                result.balance >= minimumTargetTokenAmount : "Unable to perform exact source to target token swap"
                DexSyncSwap.emitSwapEvent(
                    receiverAddress: nil,
                    sourceTokenAmount: before(sourceVault.balance),
                    receivedTargetTokenAmount: result.balance,
                    sourceToken: before(sourceVault.getType()),
                    targetToken: result.getType()
                )
            } 
        }

        /// @notice This will Swap the source token for the target token while expected targetToken amount would be fixed
        ///
        /// If the user wants to swap USDC to FLOW then the
        /// sourceToTargetTokenPath is [Type<USDC>, Type<FLOW>] and
        /// USDC would be the source token
        ///
        /// Necessary constraints
        /// - For the given source vault balance, Swapped target token amount should be
        ///   equal to `exactTargetAmount`, otherwise swap would fail.
        /// - If the swap settlement time i.e getCurrentBlock().timestamp is less than or
        ///   equal to the provided expiry then the swap would fail.
        /// - Provided `recipient` capability should be valid otherwise the swap would fail.
        /// - If the provided path doesn’t exists then the swap would fail.
        ///
        /// @param sourceToTargetTokenPath:   Off-chain computed path for reaching source token to target token
        ///                                   `sourceToTargetTokenPath[0]` should be the source token type while
        ///                                   `sourceToTargetTokenPath[sourceToTargetTokenPath.length - 1]` should be the target token
        ///                                    and all the remaining intermediaries token types would be necessary swap hops to swap the
        ///                                    source token with target token.
        /// @param sourceVault:                Vault that holds the source token.
        /// @param exactTargetAmount:          Exact amount expected from the swap, If swapped amount is different from `exactTargetAmount`
        ///                                    then function execution would throw a error.
        /// @param expiry:                     Unix timestamp after which trade would get invalidated.
        /// @param recipient:                  A valid capability that receives target token after the completion of function execution.
        /// @param remainingSourceTokenRecipient: A valid capability that receives surplus source token after the completion of function execution.
        pub fun swapSourceToExactTargetTokenUsingPath(
            sourceToTargetTokenPath: [Type],
            sourceVault: @FungibleToken.Vault,
            exactTargetAmount: UFix64,
            expiry: UFix64,
            recipient: Capability<&{FungibleToken.Receiver}>,
            remainingSourceTokenRecipient: Capability<&{FungibleToken.Receiver, FungibleToken.Balance}>
        ): UFix64
        {
            pre {
                expiry >= getCurrentBlock().timestamp : "Expired swap request"
                recipient.check() : "Provided recipient capability can not be borrowed"
                remainingSourceTokenRecipient.check() : "Provided remaining source token recipient capability can not be borrowed"
                sourceToTargetTokenPath.length >= 2 : "Incorrect source to target token path"
                sourceVault.balance > 0.0 : "Swap is not permitted for zero source vault balance"
                remainingSourceTokenRecipient.borrow()!.getSupportedVaultTypes().containsKey(sourceVault.getType()): "Provided remainingSourceTokenRecipient capability can not hold funds of source token type"
            }
            post {
                result == exactTargetAmount: "Token swap failed because the return amount did not match the specified exactTargetAmount"
                DexSyncSwap.emitSwapEvent(
                    receiverAddress: recipient.address,
                    sourceTokenAmount: before(sourceVault.balance) - remainingSourceTokenRecipient.borrow()!.balance,
                    receivedTargetTokenAmount: exactTargetAmount,
                    sourceToken: before(sourceVault.getType()),
                    targetToken: recipient.borrow()!.getSupportedVaultTypes().keys.length == 1 ? recipient.borrow()!.getSupportedVaultTypes().keys[0] : nil
                )
            }
        }

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
        pub fun swapSourceToExactTargetTokenUsingPathAndReturn(
            sourceToTargetTokenPath: [Type],
            sourceVault: @FungibleToken.Vault,
            exactTargetAmount: UFix64,
            expiry: UFix64
        ): @AnyResource{ExactSwapAndReturnValue} {
            pre {
                expiry >= getCurrentBlock().timestamp : "Expired swap request"
                sourceToTargetTokenPath.length >= 2 : "Incorrect source to target token path"
                sourceVault.balance > 0.0 : "Swap is not permitted for zero source vault balance"
            }
            post {
                result.targetTokenVault.balance == exactTargetAmount : "Token swap failed because the return targetTokenVault balance did not match the specified exactTargetAmount"
                DexSyncSwap.emitSwapEvent(
                    receiverAddress: nil,
                    sourceTokenAmount: before(sourceVault.balance) - result.remainingSourceTokenVaultAmount,
                    receivedTargetTokenAmount: exactTargetAmount,
                    sourceToken: before(sourceVault.getType()),
                    targetToken: result.targetTokenVault.getType()
                )
            } 
        }
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
            sourceToTargetTokenPath: [Type],
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
            sourceToTargetTokenPath: [Type],
            targetAmount: UFix64
        ): UFix64?

    }

    access(self) fun emitSwapEvent(receiverAddress: Address?, sourceTokenAmount: UFix64, receivedTargetTokenAmount: UFix64, sourceToken: Type, targetToken: Type?): Bool {
        emit Swap(
            receiverAddress: receiverAddress,
            sourceTokenAmount: sourceTokenAmount,
            receivedTargetTokenAmount: receivedTargetTokenAmount,
            sourceToken: sourceToken,
            targetToken: targetToken
        )
        return true
    }
}