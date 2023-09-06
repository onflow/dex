import MetadataViews from "MetadataViews"

pub contract LiquidityProviderTokenView {

    /// Helper to get the LPToken View
    pub struct LPTokenData {
        pub let pairId: String?
        init(
            pairId: String?
        ) {
            self.pairId = pairId
        }
    }

    /// Helper to get a LPToken view.
    ///
    /// @param viewResolver: A reference to the resolver resource
    /// @return A LPTokenData struct
    ///
    pub fun getLPTokenData(viewResolver: &{MetadataViews.Resolver}): LPTokenData {
        let maybeLPTokenData = viewResolver.resolveView(Type<LPTokenData>())
        if let lPTokenData = maybeLPTokenData {
            return lPTokenData as! LPTokenData
        }
        return LPTokenData(pairId: "")
    } 
}